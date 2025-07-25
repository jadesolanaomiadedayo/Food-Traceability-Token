# 🍎 Food Traceability Token

> 🌱 Blockchain-powered food safety and supply chain transparency

## 📖 Overview

The Food Traceability Token is a smart contract solution that addresses the critical need for transparent and verifiable food supply chains. Each batch of food products receives a unique NFT token that tracks its journey from farm to table.

## ✨ Key Features

- 🏷️ **Unique Batch Tokens**: Each food batch gets an NFT for complete traceability
- 📍 **Supply Chain Tracking**: Real-time location and handling updates
- 🌡️ **Environmental Monitoring**: Temperature and humidity tracking
- ✅ **Oracle Verification**: Trusted third-party validation
- 📜 **Certification Management**: Digital certificates for quality standards
- 🔍 **Freshness Verification**: Automatic age and quality checks

## 🚀 Getting Started

### Prerequisites

- [Clarinet CLI](https://docs.hiro.so/stacks/clarinet)
- [Node.js](https://nodejs.org/) (for tests)

### Installation

```bash
git clone https://github.com/your-username/Food-Traceability-Token
cd Food-Traceability-Token
clarinet check
```

## 📋 Contract Functions

### 🌾 Producer Functions

#### Create Batch
```clarity
(contract-call? .Food-Traceability-Token create-batch 
  "Organic Apples" 
  "Green Valley Farm, CA" 
  u1672531200)
```

### 🚛 Supply Chain Updates

#### Update Stage
```clarity
(contract-call? .Food-Traceability-Token update-batch-stage 
  u1 
  "Distribution Center, NY" 
  (some 4) 
  (some u65) 
  "Transported in refrigerated truck")
```

### 👨‍💼 Oracle Management

#### Add Oracle
```clarity
(contract-call? .Food-Traceability-Token add-oracle 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

#### Add Certification
```clarity
(contract-call? .Food-Traceability-Token add-certification 
  u1 
  "Organic" 
  u1704067200 
  "USDA Organic Certificate #12345")
```

### 🔍 Query Functions

#### Get Batch Information
```clarity
(contract-call? .Food-Traceability-Token get-batch-info u1)
```

#### Verify Freshness
```clarity
(contract-call? .Food-Traceability-Token verify-batch-freshness u1 u144)
```

#### Check Supply Chain Integrity
```clarity
(contract-call? .Food-Traceability-Token verify-supply-chain u1)
```

## 📊 Data Structures

### Batch Information
```clarity
{
  producer: principal,
  product-name: (string-ascii 50),
  harvest-date: uint,
  origin-location: (string-ascii 100),
  current-stage: uint,
  created-at: uint,
  certified: bool
}
```

### Supply Chain Stage
```clarity
{
  location: (string-ascii 100),
  handler: principal,
  timestamp: uint,
  temperature: (optional int),
  humidity: (optional uint),
  notes: (string-ascii 200),
  verified: bool
}
```

## 🎯 Use Cases

### 🍅 Farm to Table Tracking
1. **Producer** creates batch token at harvest
2. **Distributors** update location and conditions
3. **Retailers** verify authenticity and freshness
4. **Consumers** scan QR code for complete history

### 🏛️ Regulatory Compliance
- Health inspectors verify supply chain integrity
- Automatic freshness alerts for expired products
- Certification tracking for organic/fair-trade products

### 🔒 Food Safety Response
- Instant batch recall capabilities
- Temperature abuse detection
- Contamination source identification

## ⚡ Testing

```bash
npm install
npm test
```

## 🛡️ Security Features

- **Oracle Authorization**: Only verified oracles can update critical data
- **Ownership Verification**: Batch owners control their tokens
- **Immutable History**: All supply chain events are permanently recorded
- **Data Integrity**: Cryptographic verification of all updates

## 🌍 Impact

- 🛡️ **Enhanced Food Safety**: Rapid identification of contamination sources
- 🤝 **Consumer Trust**: Complete transparency in food origins
- ♻️ **Sustainable Sourcing**: Verification of ethical farming practices
- 📈 **Supply Chain Efficiency**: Real-time tracking and optimization

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📞 Support

- 📧 Email: support@foodtrace.example
- 💬 Discord: [Food Traceability Community](https://discord.gg/foodtrace)
- 📖 Documentation: [docs.foodtrace.example](https://docs.foodtrace.example)

---

*🌱 Building a more transparent and safer food system, one batch at a time.*
