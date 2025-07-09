#!/bin/bash

# Repository Deployment Script for Amazon Linux
# Usage: ./deploy.sh <repository_url> [branch_name] [app_name]

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="$1"
BRANCH_NAME="${2:-main}"
APP_NAME="${3:-myapp}"
DEPLOY_DIR="/var/www"
APP_DIR="$DEPLOY_DIR/$APP_NAME"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if repository URL is provided
if [ -z "$REPO_URL" ]; then
    print_error "Repository URL is required!"
    echo "Usage: $0 <repository_url> [branch_name] [app_name]"
    echo "Example: $0 https://github.com/user/repo.git main myapp"
    exit 1
fi

print_status "Starting deployment for $APP_NAME from $REPO_URL (branch: $BRANCH_NAME)"

# Update system packages
print_status "Updating system packages..."
sudo yum update -y

# Install Git if not present
print_status "Installing Git..."
sudo yum install -y git

# Install Node.js and npm (using NodeSource repository for latest LTS)
print_status "Installing Node.js and npm..."
curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
sudo yum install -y nodejs

# Verify Node.js and npm installation
print_status "Node.js version: $(node --version)"
print_status "npm version: $(npm --version)"

# Install PM2 globally
print_status "Installing PM2 globally..."
sudo npm install -g pm2

# Create deployment directory
print_status "Creating deployment directory..."
sudo mkdir -p $DEPLOY_DIR
sudo chown -R ec2-user:ec2-user $DEPLOY_DIR

# Remove existing application directory if it exists
if [ -d "$APP_DIR" ]; then
    print_warning "Removing existing application directory..."
    rm -rf $APP_DIR
fi

# Clone repository
print_status "Cloning repository..."
cd $DEPLOY_DIR
git clone -b $BRANCH_NAME $REPO_URL $APP_NAME

# Navigate to application directory
cd $APP_DIR

# Install dependencies
print_status "Installing dependencies..."
npm install

# Create logs directory for future PM2 usage
mkdir -p logs

# Create example PM2 ecosystem file for reference
print_status "Creating example PM2 ecosystem configuration..."
cat > ecosystem.config.js.example << EOF
module.exports = {
  apps: [
    {
      name: 'service1',
      script: './services/service1/index.js',
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
      env: {
        NODE_ENV: 'production',
        PORT: 3001
      },
      error_file: './logs/service1-err.log',
      out_file: './logs/service1-out.log',
      log_file: './logs/service1-combined.log',
      time: true
    },
    {
      name: 'service2',
      script: './services/service2/index.js',
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
      env: {
        NODE_ENV: 'production',
        PORT: 3002
      },
      error_file: './logs/service2-err.log',
      out_file: './logs/service2-out.log',
      log_file: './logs/service2-combined.log',
      time: true
    }
  ]
};
EOF

print_status "Skipping PM2 application start - ready for manual microservice deployment"

# Setup PM2 to start on boot (without starting any apps yet)
print_status "Setting up PM2 to start on system boot..."
pm2 startup systemd -u ec2-user --hp /home/ec2-user

# Install and configure nginx (optional)
read -p "Do you want to install and configure Nginx as reverse proxy? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Installing Nginx..."
    sudo yum install -y nginx
    
    # Create basic nginx configuration (to be updated later for microservices)
    print_status "Configuring Nginx for microservices..."
    sudo tee /etc/nginx/conf.d/$APP_NAME.conf > /dev/null << EOF
# Nginx configuration for microservices
# Update this file after deploying your microservices

server {
    listen 80;
    server_name localhost;

    # Example service routing - update paths and ports as needed
    # location /api/service1 {
    #     proxy_pass http://localhost:3001;
    #     proxy_http_version 1.1;
    #     proxy_set_header Upgrade \$http_upgrade;
    #     proxy_set_header Connection 'upgrade';
    #     proxy_set_header Host \$host;
    #     proxy_set_header X-Real-IP \$remote_addr;
    #     proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    #     proxy_set_header X-Forwarded-Proto \$scheme;
    #     proxy_cache_bypass \$http_upgrade;
    # }

    # location /api/service2 {
    #     proxy_pass http://localhost:3002;
    #     proxy_http_version 1.1;
    #     proxy_set_header Upgrade \$http_upgrade;
    #     proxy_set_header Connection 'upgrade';
    #     proxy_set_header Host \$host;
    #     proxy_set_header X-Real-IP \$remote_addr;
    #     proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    #     proxy_set_header X-Forwarded-Proto \$scheme;
    #     proxy_cache_bypass \$http_upgrade;
    # }

    location / {
        return 200 'Server is ready for microservice deployment';
        add_header Content-Type text/plain;
    }
}
EOF

    # Start and enable nginx
    sudo systemctl start nginx
    sudo systemctl enable nginx
    
    print_status "Nginx configured and started (ready for microservice configuration)"
fi

# Set up firewall for microservices
print_status "Configuring firewall for microservices..."
sudo yum install -y firewalld
sudo systemctl start firewalld
sudo systemctl enable firewalld
sudo firewall-cmd --permanent --add-port=3000-3010/tcp  # Range for microservices
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload

# Display final status
print_status "Setup completed successfully!"
echo
echo "Application Details:"
echo "==================="
echo "App Name: $APP_NAME"
echo "Directory: $APP_DIR"
echo "Repository: $REPO_URL"
echo "Branch: $BRANCH_NAME"
echo
echo "Setup Status:"
echo "- Repository cloned ✓"
echo "- Dependencies installed ✓"
echo "- PM2 installed and configured ✓"
echo "- Logs directory created ✓"
echo "- Example ecosystem.config.js created ✓"
if systemctl is-active --quiet nginx; then
    echo "- Nginx installed and running ✓"
fi
echo
echo "Next Steps for Microservice Deployment:"
echo "======================================="
echo "1. Navigate to your app directory: cd $APP_DIR"
echo "2. Create or modify ecosystem.config.js based on your microservices"
echo "3. Start your microservices: pm2 start ecosystem.config.js"
echo "4. Save PM2 configuration: pm2 save"
echo "5. Update Nginx configuration if needed: sudo nano /etc/nginx/conf.d/$APP_NAME.conf"
echo
echo "Example PM2 commands for microservices:"
echo "- Start specific service: pm2 start ecosystem.config.js --only service1"
echo "- View all services: pm2 status"
echo "- View logs: pm2 logs [service-name]"
echo "- Restart service: pm2 restart [service-name]"
echo "- Stop service: pm2 stop [service-name]"
echo
echo "Server IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "App directory: $APP_DIR"
echo "Example ecosystem file: $APP_DIR/ecosystem.config.js.example"

print_status "Server is ready for microservice deployment!"