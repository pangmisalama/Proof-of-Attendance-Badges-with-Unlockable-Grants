# 🎓 Proof-of-Attendance Badges with Unlockable Grants

A Clarity smart contract that issues attendance badges for training sessions and unlocks conditional grants to incentivize upskilling. 

## 🌟 Features

- 📜 **Training Management**: Create and manage training sessions
- 🎖️ **Badge Minting**: Issue proof-of-attendance badges to participants  
- 💰 **Conditional Grants**: Unlock STX grants based on badge collection
- 👥 **Attendance Tracking**: Verify and record training participation
- ⏰ **Time-based Controls**: Enforce training schedules and grant expiration

## 🚀 Quick Start

### Deploy the Contract

```bash
clarinet deployments apply --devnet
```

### Basic Usage Flow

1. **Create Training** (Instructor/Owner)
```clarity
(contract-call? .Proof-of-Attendance-Badges create-training "Blockchain Basics" u100 u50)
```

2. **Register Attendance** (Instructor)  
```clarity
(contract-call? .Proof-of-Attendance-Badges register-attendance u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

3. **Mint Badge** (Participant - after training ends)
```clarity
(contract-call? .Proof-of-Attendance-Badges mint-badge u1 "Completed Blockchain Basics Training")
```

4. **Create Grant** (Grant Creator)
```clarity
(contract-call? .Proof-of-Attendance-Badges create-grant u1000000 u3 u1000)
```

5. **Claim Grant** (Badge Holder)
```clarity
(contract-call? .Proof-of-Attendance-Badges claim-grant u1)
```

## 📋 Contract Functions

### Public Functions

| Function | Description | Access |
|----------|-------------|--------|
| `create-training` | Create new training session | Owner only |
| `register-attendance` | Mark user as attended | Instructor |
| `mint-badge` | Issue badge to attendee | Attendee |
| `create-grant` | Fund new conditional grant | Anyone |
| `claim-grant` | Claim grant with badges | Badge holders |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-badge` | Get badge details |
| `get-training` | Get training information |
| `get-grant` | Get grant details |
| `get-user-badges` | Get user's badge collection |
| `get-attendance` | Check attendance record |
| `has-claimed-grant` | Check if grant claimed |

## 💡 Use Cases

- 🎯 **Corporate Training**: Incentivize employee skill development
- 🏫 **Educational Institutions**: Reward course completion  
- 🤝 **Community Workshops**: Build engaged learning communities
- 🚀 **Developer Bootcamps**: Motivate participation with micro-grants
- 🔬 **Research Programs**: Fund continued learning initiatives

## 🔧 Development

### Prerequisites

- [Clarinet](https://docs.hiro.so/clarinet)
- [Stacks CLI](https://docs.stacks.co/docs/command-line-interface)

### Testing

```bash
clarinet test
```

### Console

```bash
clarinet console
```

## 📊 Data Structure

The contract manages three main entities:

- **🎓 Trainings**: Sessions with instructors, schedules, and capacity
- **🏆 Badges**: Proof-of-attendance tokens tied to specific trainings  
- **💎 Grants**: STX-funded rewards unlocked by badge collection

## ⚡ Gas Optimization

The contract is optimized for minimal transaction costs while maintaining security and functionality.

## 🔒 Security Features

- Owner-only training creation
- Instructor-controlled attendance verification
- Time-locked badge minting (post-training)
- Anti-double-claim protection
- Grant fund management

## 📈 Scaling Considerations

- Maximum 100 badges per user (adjustable)
- Training capacity limits enforced
- Block-height based timing controls
- Efficient map-based data storage

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Write tests for new functionality  
4. Ensure all tests pass
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

---

*Built with ❤️ on Stacks blockchain*
