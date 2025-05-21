
const express = require("express")
const mongoose = require("mongoose")
const bcrypt = require("bcryptjs")
const jwt = require("jsonwebtoken")
const cors = require("cors")
const dotenv = require("dotenv")


dotenv.config()

// const accountSid = process.env.TWILIO_ACCOUNT_SID;
// const authToken = process.env.TWILIO_AUTH_TOKEN;
const twilioPhoneNumber = process.env.TWILIO_PHONE_NUMBER;
const client = require('twilio')(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);



const app = express()

// Middleware
app.use(cors())
app.use(express.json())


mongoose
  .connect(process.env.MONGODB_URI || "mongodb://localhost:27017/autoshop", {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  })
  .then(() => console.log("MongoDB connected"))
  .catch((err) => console.error("MongoDB connection error:", err))


const userSchema = new mongoose.Schema({
  username: { type: String, required: true, unique: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
})

const customerSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true },
  phone: { type: String, required: true },
  address: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
})

const productSchema = new mongoose.Schema({
  name: { type: String, required: true },
  description: { type: String, required: true },
  price: { type: Number, required: true },
  stock: { type: Number, required: true, default: 0 },
  category: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
})

const invoiceItemSchema = new mongoose.Schema({
  product: { type: mongoose.Schema.Types.ObjectId, ref: "Product", required: true },
  quantity: { type: Number, required: true },
  price: { type: Number, required: true },
  total: { type: Number, required: true },
})

// Add a counter collection for invoice numbers
const counterSchema = new mongoose.Schema({
  _id: { type: String, required: true },
  seq: { type: Number, default: 0 }
});

const Counter = mongoose.model('Counter', counterSchema);

const invoiceSchema = new mongoose.Schema({
  invoiceNumber: { type: String, required: true, unique: true },
  customer: { type: mongoose.Schema.Types.ObjectId, ref: "Customer", required: true },
  items: [invoiceItemSchema],
  total: { type: Number, required: true },
  date: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
})

// Create Models
const User = mongoose.model("User", userSchema)
const Customer = mongoose.model("Customer", customerSchema)
const Product = mongoose.model("Product", productSchema)
const Invoice = mongoose.model("Invoice", invoiceSchema)

// Function to get the next invoice number
async function getNextInvoiceNumber() {
  const counter = await Counter.findByIdAndUpdate(
    { _id: 'invoiceNumber' },
    { $inc: { seq: 1 } },
    { new: true, upsert: true }
  );
  return `INV-${counter.seq.toString().padStart(5, '0')}`;
}

// Authentication Middleware
const auth = async (req, res, next) => {
  try {
    const token = req.header("Authorization").replace("Bearer ", "")
    const decoded = jwt.verify(token, process.env.JWT_SECRET || "your_jwt_secret")
    const user = await User.findById(decoded.id)
    if (!user) {
      throw new Error();
    }
    req.token = token;
    req.user = user;
    next();
  } catch (error) {
    res.status(401).send({ error: "Please authenticate" })
  }
}

// Function to send SMS - Fixed implementation
async function sendSms(to, message) {
  try {
    // Format the phone number to include country code if needed
    const formattedNumber = to.startsWith('+') ? to : `+91${to}`; // Assuming India
    
    const messageResponse = await client.messages.create({
      body: message,
      to: formattedNumber,
      from: twilioPhoneNumber, // Use the environment variable
    });
    
    console.log('SMS sent:', messageResponse.sid);
    return messageResponse;
  } catch (error) {
    console.error('Error sending SMS:', error);
    throw error; // Re-throw to handle in the calling function
  }
}

// Routes
// User Registration
app.post("/api/register", async (req, res) => {
  try {
    const { username, email, password } = req.body
    // Check if user already exists
    const existingUser = await User.findOne({ $or: [{ email }, { username }] })
    if (existingUser) {
      return res.status(400).json({ error: "User already exists" })
    }
    // Hash password
    const salt = await bcrypt.genSalt(10)
    const hashedPassword = await bcrypt.hash(password, salt)
    // Create new user
    const user = new User({
      username,
      email,
      password: hashedPassword,
    })
    await user.save()
    // Generate JWT token
    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET || "your_jwt_secret", { expiresIn: "30d" })
    res.status(201).json({
      token,
      user: {
        id: user._id,
        username: user.username,
        email: user.email,
      },
    })
  } catch (error) {
    console.error("Registration error:", error)
    res.status(500).json({ error: "Server error" })
  }
})

// User Login
app.post("/api/login", async (req, res) => {
  try {
    const { email, password } = req.body
    // Find user by email
    const user = await User.findOne({ email })
    if (!user) {
      return res.status(400).json({ error: "Invalid credentials" })
    }
    // Check password
    const isMatch = await bcrypt.compare(password, user.password)
    if (!isMatch) {
      return res.status(400).json({ error: "Invalid credentials" })
    }
    // Generate JWT token
    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET || "your_jwt_secret", { expiresIn: "30d" })
    res.json({
      token,
      user: {
        id: user._id,
        username: user.username,
        email: user.email,
      },
    })
  } catch (error) {
    console.error("Login error:", error)
    res.status(500).json({ error: "Server error" })
  }
})

// Customer Routes
// Get all customers
app.get("/api/customers", auth, async (req, res) => {
  try {
    const customers = await Customer.find().sort({ createdAt: -1 })
    res.json(customers)
  } catch (error) {
    console.error("Get customers error:", error)
    res.status(500).json({ error: "Server error" })
  }
})

// Get customer by ID
app.get("/api/customers/:id", auth, async (req, res) => {
  try {
    // Validate ObjectId before querying
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(404).json({ error: "Invalid customer ID format" })
    }
    
    const customer = await Customer.findById(req.params.id)
    if (!customer) {
      return res.status(404).json({ error: "Customer not found" })
    }
    res.json(customer)
  } catch (error) {
    console.error("Get customer error:", error)
    res.status(500).json({ error: "Server error" })
  }
})

// Create customer
// Example: Customer creation route
app.post('/api/customers', async (req, res) => {
  try {
    const { email, phone } = req.body;
    // Check for duplicate email
    const existingEmail = await Customer.findOne({ email });
    if (existingEmail) {
      return res.status(400).json({ error: 'Customer with this email already exists' });
    }
    // Check for duplicate phone number
    const existingPhone = await Customer.findOne({ phone });
    if (existingPhone) {
      return res.status(400).json({ error: 'Customer with this phone number already exists' });
    }
    // Create new customer
    const customer = new Customer(req.body);
    await customer.save();
    res.status(201).json({ message: 'Customer created successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Server error' });
  }
});

// Update customer
app.put("/api/customers/:id", auth, async (req, res) => {
  try {
    // Validate ObjectId before querying
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(404).json({ error: "Invalid customer ID format" })
    }
    
    const { name, email, phone, address } = req.body
    const customer = await Customer.findByIdAndUpdate(req.params.id, { name, email, phone, address }, { new: true })
    if (!customer) {
      return res.status(404).json({ error: "Customer not found" })
    }
    res.json(customer)
  } catch (error) {
    console.error("Update customer error:", error)
    res.status(500).json({ error: "Server error" })
  }
})

// Delete customer
app.delete("/api/customers/:id", auth, async (req, res) => {
  try {
    // Validate ObjectId before querying
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(404).json({ error: "Invalid customer ID format" })
    }
    
    const customer = await Customer.findByIdAndDelete(req.params.id)
    if (!customer) {
      return res.status(404).json({ error: "Customer not found" })
    }
    res.json({ message: "Customer deleted" })
  } catch (error) {
    console.error("Delete customer error:", error)
    res.status(500).json({ error: "Server error" })
  }
})

// Product Routes
// Get all products
app.get("/api/products", auth, async (req, res) => {
  try {
    const { category } = req.query; // Get category from query parameters
    let products;
    if (category) {
      products = await Product.find({ category }).sort({ createdAt: -1 }); // Filter by category
    } else {
      products = await Product.find().sort({ createdAt: -1 }); // Return all products
    }
    res.json(products);
  } catch (error) {
    console.error("Get products error:", error);
    res.status(500).json({ error: "Server error" });
  }
});

// Get product by ID
app.get("/api/products/:id", auth, async (req, res) => {
  try {
    // Validate ObjectId before querying
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(404).json({ error: "Invalid product ID format" })
    }
    
    const product = await Product.findById(req.params.id)
    if (!product) {
      return res.status(404).json({ error: "Product not found" })
    }
    res.json(product)
  } catch (error) {
    console.error("Get product error:", error)
    res.status(500).json({ error: "Server error" })
  }
})

// Create product
app.post("/api/products", auth, async (req, res) => {
  try {
    console.log("Request Body:", req.body); // Log the request body
    const { name, description, price, stock, category } = req.body;
    if (!category) {
      return res.status(400).json({ error: "Category is required" });
    }
    
    const product = new Product({
      name,
      description,
      price,
      stock,
      category,
    });
    const existingProduct = await Product.findOne({ name });
    if (existingProduct) {
      return res.status(400).json({ error: 'Product with this name already exists' });
    }
    await product.save();
    res.status(201).json({ message: 'Product created successfully', product });
  } catch (error) {
    console.error("Create product error:", error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Update product
app.put("/api/products/:id", auth, async (req, res) => {
  try {
    // Validate ObjectId before querying
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(404).json({ error: "Invalid product ID format" });
    }
    const { name, description, price, stock, category } = req.body;
    // Validate
    const validCategories = ["Engine Parts", "Suspension and Steering", "Braking System", "Electrical Components","Oil" ,"Transmission and Drivetrain", "Cooling System", "Exhaust System", "Body Parts", "Interior Components", "Filters", "Fuel System", "Wheels and Tires", "Accessories", "Maintenance Parts", "Lighting and Electrical", "Heating and Air Conditioning"];
    if (!validCategories.includes(category)) {
      return res.status(400).json({ error: "Invalid category" });
    }
    const product = await Product.findByIdAndUpdate(
      req.params.id,
      { name, description, price, stock, category }, // Update category
      { new: true }
    );
    if (!product) {
      return res.status(404).json({ error: "Product not found" });
    }
    res.json(product);
  } catch (error) {
    console.error("Update product error:", error);
    res.status(500).json({ error: "Server error" });
  }
});

// Delete product
app.delete("/api/products/:id", auth, async (req, res) => {
  try {
    // Validate ObjectId before querying
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(404).json({ error: "Invalid product ID format" })
    }
    
    const product = await Product.findByIdAndDelete(req.params.id)
    if (!product) {
      return res.status(404).json({ error: "Product not found" })
    }
    res.json({ message: "Product deleted" })
  } catch (error) {
    console.error("Delete product error:", error)
    res.status(500).json({ error: "Server error" })
  }
})

// Invoice Routes
// Get all invoices
app.get("/api/invoices", auth, async (req, res) => {
  try {
    const invoices = await Invoice.find()
      .populate("customer")
      .populate("items.product")
      .sort({ createdAt: -1 })
    res.json(invoices)
  } catch (error) {
    console.error("Get invoices error:", error)
    res.status(500).json({ error: "Server error" })
  }
})

// Get invoice by ID
app.get("/api/invoices/:id", auth, async (req, res) => {
  try {
    // Validate ObjectId before querying
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(404).json({ error: "Invalid invoice ID format" })
    }
    
    const invoice = await Invoice.findById(req.params.id)
      .populate("customer")
      .populate("items.product")
    if (!invoice) {
      return res.status(404).json({ error: "Invoice not found" })
    }
    res.json(invoice)
  } catch (error) {
    console.error("Get invoice error:", error)
    res.status(500).json({ error: "Server error" })
  }
})

// Create invoice with SMS notification
app.post("/api/invoices", auth, async (req, res) => {
  try {
    const { customer, items, total, date } = req.body
    
    // Validate customer ID
    if (!mongoose.Types.ObjectId.isValid(customer)) {
      return res.status(400).json({ error: "Invalid customer ID format" })
    }
    
    // Validate customer exists
    const customerExists = await Customer.findById(customer)
    if (!customerExists) {
      return res.status(404).json({ error: "Customer not found" })
    }
    
    // Validate items
    for (const item of items) {
      if (!mongoose.Types.ObjectId.isValid(item.product)) {
        return res.status(400).json({ error: "Invalid product ID format" })
      }
      
      // Check product exists and has enough stock
      const product = await Product.findById(item.product)
      if (!product) {
        return res.status(404).json({ error: `Product with ID ${item.product} not found` })
      }
      
      if (product.stock < item.quantity) {
        return res.status(400).json({
          error: `Not enough stock for product ${product.name}. Available: ${product.stock}, Requested: ${item.quantity}`
        })
      }
      
      // Update product stock
      product.stock -= item.quantity
      await product.save()
    }
    
    // Generate invoice number
    const invoiceNumber = await getNextInvoiceNumber()
    
    // Create invoice
    const invoice = new Invoice({
      invoiceNumber,
      customer,
      items: items.map(item => ({
        product: item.product,
        quantity: item.quantity,
        price: item.price,
        total: item.quantity * item.price
      })),
      total,
      date
    })
    
    await invoice.save()
    
    // Fetch the complete invoice with populated fields for SMS
    const populatedInvoice = await Invoice.findById(invoice._id)
      .populate("customer")
      .populate("items.product");
    
    
    try {
      const customerPhone = customerExists.phone;
      const invoiceDetails = `Invoice Number: ${invoiceNumber}\nTotal: ₹${total}\nDate: ${date}`;
      const smsMessage = `Hello ${customerExists.name}, your invoice from Durai Auto Parts has been created successfully!\n${invoiceDetails}`;
      
      await sendSms(customerPhone, smsMessage);
      console.log('Invoice notification SMS sent to customer');
    } catch (smsError) {
      console.error('Error sending invoice SMS:', smsError);
      // Continue with the response even if SMS fails
    }
    
    res.status(201).json(populatedInvoice)
  } catch (error) {
    console.error("Create invoice error:", error)
    res.status(500).json({ error: "Server error: " + error.message })
  }
})

app.get("/api/categories", auth, async (req, res) => {
  try {
    const categories = await Product.distinct("category"); // Get unique categories
    res.json(categories);
  } catch (error) {
    console.error("Get categories error:", error);
    res.status(500).json({ error: "Server error" });
  }
});

// Delete invoice
app.delete("/api/invoices/:id", auth, async (req, res) => {
  try {
    // Validate ObjectId before querying
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(404).json({ error: "Invalid invoice ID format" })
    }
    
    const invoice = await Invoice.findByIdAndDelete(req.params.id)
    if (!invoice) {
      return res.status(404).json({ error: "Invoice not found" })
    }
    res.json({ message: "Invoice deleted" })
  } catch (error) {
    console.error("Delete invoice error:", error)
    res.status(500).json({ error: "Server error" })
  }
})

// API endpoint to send SMS manually
app.post('/api/send-sms', auth, async (req, res) => {
  const { to, message } = req.body;
  
  if (!to || !message) {
    return res.status(400).json({ error: 'Phone number and message are required' });
  }
  
  try {
    await sendSms(to, message);
    res.status(200).json({ success: true, message: 'SMS sent successfully' });
  } catch (error) {
    console.error('SMS sending error:', error);
    res.status(500).json({ 
      error: 'Failed to send SMS', 
      details: error.message 
    });
  }
});

// Start the server
const PORT = process.env.PORT || 3000
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`)
})