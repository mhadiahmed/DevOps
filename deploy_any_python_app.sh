#!/bin/bas

# Set up variables
APP_NAME="<your-app-name>"
APP_DIR="/home/ec2-user/$APP_NAME"
VENV_DIR="$APP_DIR/venv"
REPO_URL="<your-repo-url>":
DOMAIN="<your-domain>"
SOCK_FILE="$APP_DIR/$APP_NAME.sock"

# Update the system and install dependencies
sudo yum update -y
sudo yum install python3 python3-pip nginx git -y

# Clone the app repository
git clone $REPO_URL $APP_DIR
cd $APP_DIR

# Set up a virtual environment and install dependencies
sudo pip3 install virtualenv
virtualenv -p python3 $VENV_DIR
source $VENV_DIR/bin/activate
pip3 install -r requirements.txt

# Test the app with Gunicorn
gunicorn --bind 0.0.0.0:8000 app:app &

# Create a systemd service for the app
sudo tee /etc/systemd/system/$APP_NAME.service > /dev/null <<EOT
[Unit]
Description=Gunicorn instance to serve $APP_NAME
After=network.target

[Service]
User=ec2-user
Group=nginx
WorkingDirectory=$APP_DIR
Environment="PATH=$VENV_DIR/bin"
ExecStart=$VENV_DIR/bin/gunicorn --workers 3 --bind unix:$SOCK_FILE -m 007 app:app

[Install]
WantedBy=multi-user.target
EOT

# Start and enable the service
sudo systemctl start $APP_NAME
sudo systemctl enable $APP_NAME

# Configure Nginx to serve the app
sudo tee /etc/nginx/conf.d/$APP_NAME.conf > /dev/null <<EOT
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        include proxy_params;
        proxy_pass http://unix:$SOCK_FILE;
    }
}
EOT

# Test the Nginx configuration and restart Nginx
sudo nginx -t
sudo systemctl restart nginxh
