#### Installation
```bash
# update inventory.ini host and user
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory.ini hello.yml
ansible-playbook -i inventory.ini docker.yml
ansible-playbook -i inventory.ini immich.yml
ansible-playbook -i inventory.ini nginx.yml

# temp workaround with certbot
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
sudo certbot certonly --nginx
```

#### Benchmark
```bash
# install dependencies 
sudo add-apt-repository ppa:unit193/encryption
sudo apt update
sudo apt install zfsutils-linux ecryptfs-utils fscrypt veracrypt

# prepare payload - folder_name is the input
tar -cf payload.tar folder_name

# run benchmark
./benchmark.sh

# output in Markdown 
pandoc benchmark.md -o benchmark.html
```