const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const dotenv = require('dotenv');

// Load environment variables
dotenv.config();

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// MongoDB Connection with error handling
mongoose.connect(process.env.MONGODB_URI)
  .then(() => {
    console.log('Connected to MongoDB successfully');
  })
  .catch((error) => {
    console.error('MongoDB connection error:', error);
    process.exit(1);
  });

  const validateEmail = (email) => {
    const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return re.test(email);
};

// Enhanced validation for phone
const validatePhone = (phone) => {
    const re = /^\+?[\d\s-]{10,}$/;
    return re.test(phone);
};
// Models
const customerSchema = new mongoose.Schema({
    name: { 
        type: String, 
        required: [true, 'Name is required'],
        trim: true,
        minlength: [2, 'Name must be at least 2 characters long']
    },
    email: { 
        type: String, 
        required: [true, 'Email is required'],
        unique: true,
        trim: true,
        validate: {
            validator: validateEmail,
            message: 'Please enter a valid email address'
        }
    },
    phone: { 
        type: String, 
        required: [true, 'Phone number is required'],
        validate: {
            validator: validatePhone,
            message: 'Please enter a valid phone number'
        }
    },
    address: String,
    createdAt: { type: Date, default: Date.now }
});

const productSchema = new mongoose.Schema({
    name: { 
        type: String, 
        required: [true, 'Product name is required'],
        trim: true,
        minlength: [2, 'Product name must be at least 2 characters long']
    },
    code: { 
        type: String, 
        required: [true, 'Product code is required'],
        unique: true,
        trim: true,
        uppercase: true
    },
    price: { 
        type: Number, 
        required: [true, 'Price is required'],
        validate: {
            validator: (value) => value >= 0,
            message: 'Price cannot be negative'
        }
    },
     stock: { 
        type: Number, 
        required: [true, 'Stock quantity is required'],
        validate: [
            {
                validator: Number.isInteger,
                message: 'Stock must be a whole number'
            },
            {
                validator: (value) => value >= 0,
                message: 'Stock cannot be negative'
            }
        ]
    },
    category: String,
    description: String
});

const invoiceSchema = new mongoose.Schema({
    invoiceNumber: { 
        type: String, 
        required: true, 
        unique: true 
    },
    customer: { 
        type: mongoose.Schema.Types.ObjectId, 
        ref: 'Customer',
        required: true
    },
    items: [{
        product: { 
            type: mongoose.Schema.Types.ObjectId, 
            ref: 'Product',
            required: true
        },
        quantity: {
            type: Number,
            required: true,
            min: [1, 'Quantity must be at least 1']
        },
        price: {
            type: Number,
            required: true,
            min: [0, 'Price cannot be negative']
        },
        subtotal: {
            type: Number,
            required: true,
            min: [0, 'Subtotal cannot be negative']
        }
    }],
    totalAmount: {
        type: Number,
        required: true,
        min: [0, 'Total amount cannot be negative']
    },
    tax: {
        type: Number,
        required: true,
        min: [0, 'Tax cannot be negative']
    },
    grandTotal: {
        type: Number,
        required: true,
        min: [0, 'Grand total cannot be negative']
    },
    date: { type: Date, default: Date.now },
    status: { 
        type: String, 
        default: 'paid',
        enum: ['paid', 'pending', 'cancelled']
    }
});

const Customer = mongoose.model('Customer', customerSchema);
const Product = mongoose.model('Product', productSchema);
const Invoice = mongoose.model('Invoice', invoiceSchema);

// Routes
// Customer Routes
app.post('/api/customers', async (req, res) => {
    try {
        // Check for existing customer with same email
        const existingCustomer = await Customer.findOne({ email: req.body.email });
        if (existingCustomer) {
            return res.status(400).json({ 
                error: 'A customer with this email already exists' 
            });
        }

        const customer = new Customer(req.body);
        await customer.save();
        res.status(201).json(customer);
    } catch (error) {
        if (error.name === 'ValidationError') {
            const errors = Object.values(error.errors).map(err => err.message);
            res.status(400).json({ errors });
        } else {
            res.status(500).json({ error: 'Internal server error' });
        }
    }
});

app.get('/api/customers/search', async (req, res) => {
    try {
        const { query } = req.query;
        if (!query) {
            return res.status(400).json({ error: 'Search query is required' });
        }

        const customers = await Customer.find({
            $or: [
                { name: new RegExp(query, 'i') },
                { phone: new RegExp(query, 'i') },
                { email: new RegExp(query, 'i') }
            ]
        });
        res.json(customers);
    } catch (error) {
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Enhanced Product Routes
app.post('/api/products', async (req, res) => {
    try {
        // Check for existing product with same code
        const existingProduct = await Product.findOne({ code: req.body.code });
        if (existingProduct) {
            return res.status(400).json({ 
                error: 'A product with this code already exists' 
            });
        }

        const product = new Product(req.body);
        await product.save();
        res.status(201).json(product);
    } catch (error) {
        if (error.name === 'ValidationError') {
            const errors = Object.values(error.errors).map(err => err.message);
            res.status(400).json({ errors });
        } else {
            res.status(500).json({ error: 'Internal server error' });
        }
    }
});

app.get('/api/products', async (req, res) => {
    try {
        const { category, search } = req.query;
        let query = {};

        if (category) {
            query.category = category;
        }

        if (search) {
            query.$or = [
                { name: new RegExp(search, 'i') },
                { code: new RegExp(search, 'i') }
            ];
        }

        const products = await Product.find(query);
        res.json(products);
    } catch (error) {
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.put('/api/products/:id/stock', async (req, res) => {
    try {
        const { id } = req.params;
        const { quantity } = req.body;

        if (!Number.isInteger(quantity) || quantity < 0) {
            return res.status(400).json({ 
                error: 'Stock quantity must be a non-negative integer' 
            });
        }

        const product = await Product.findByIdAndUpdate(
            id,
            { stock: quantity },
            { new: true, runValidators: true }
        );

        if (!product) {
            return res.status(404).json({ error: 'Product not found' });
        }

        res.json(product);
    } catch (error) {
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Invoice Routes
app.post("/api/invoices", async (req, res) => {
    const session = await mongoose.startSession()
    session.startTransaction()
  
    try {
      const { customer, items, totalAmount, tax, grandTotal } = req.body
  
      // Validate input
      if (!customer || !items || items.length === 0 || !totalAmount || !tax || !grandTotal) {
        throw new Error("Invalid input: Missing required fields")
      }
  
      // Generate invoice number
      const count = await Invoice.countDocuments()
      const invoiceNumber = `INV${String(count + 1).padStart(6, "0")}`
  
      // Update product stock and validate
      for (const item of items) {
        const product = await Product.findById(item.product).session(session)
        if (!product) {
          throw new Error(`Product not found: ${item.product}`)
        }
        if (product.stock < item.quantity) {
          throw new Error(`Insufficient stock for product: ${product.name}`)
        }
        product.stock -= item.quantity
        await product.save({ session })
      }
  
      // Create invoice
      const invoice = new Invoice({
        invoiceNumber,
        customer,
        items,
        totalAmount,
        tax,
        grandTotal,
        date: new Date(),
        status: "paid",
      })
      await invoice.save({ session })
  
      await session.commitTransaction()
      res.status(201).json(invoice)
    } catch (error) {
      await session.abortTransaction()
      res.status(400).json({ error: error.message })
    } finally {
      session.endSession()
    }
  })

app.get('/api/invoices', async (req, res) => {
    try {
        const invoices = await Invoice.find()
            .populate('customer')
            .populate('items.product');
        res.json(invoices);
    } catch (error) {
        res.status(400).json({ error: error.message });
    }
});


// Add these routes to your server.js file

// Delete product
app.delete('/api/products/:id', async (req, res) => {
    try {
      const product = await Product.findByIdAndDelete(req.params.id);
      if (!product) {
        return res.status(404).json({ error: 'Product not found' });
      }
      res.json({ message: 'Product deleted successfully' });
    } catch (error) {
      res.status(500).json({ error: 'Internal server error' });
    }
  });
  
  // Update product
  app.put('/api/products/:id', async (req, res) => {
    try {
      const product = await Product.findByIdAndUpdate(
        req.params.id,
        req.body,
        { new: true, runValidators: true }
      );
      if (!product) {
        return res.status(404).json({ error: 'Product not found' });
      }
      res.json(product);
    } catch (error) {
      if (error.name === 'ValidationError') {
        const errors = Object.values(error.errors).map(err => err.message);
        res.status(400).json({ errors });
      } else {
        res.status(500).json({ error: 'Internal server error' });
      }
    }
  });

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});