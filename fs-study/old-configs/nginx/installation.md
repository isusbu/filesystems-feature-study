# Installation

Installation commands on Ubuntu:

```bash
sudo apt update
sudo apt install nginx -y

# copy the current configs into the installed Nginx
sudo cp etc_nginx_conf.d_default.conf /etc/nginx/conf.d/default.conf
sudo cp etc_nginx_nginx.conf /etc/nginx/nginx.conf

# start Nginx instance
sudo systemctl enable nginx
sudo systemctl start nginx
```

## NOTE (firewall)

Adjust the firewall if needed.

```bash
sudo ufw allow 'Nginx Full'
sudo ufw status
```
