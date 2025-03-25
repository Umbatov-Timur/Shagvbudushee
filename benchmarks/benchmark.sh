#!/bin/bash

#### Prepare
echo "| Encryption | Write throughput | Read throughput |" >> benchmark.md
echo "|-|-|-|" >> benchmark.md

#### Baseline
echo -n "| Baseline | " >> benchmark.md && \
    cat ./payload.tar | dd of=./payload2.tar bs=4M status=progress 2>&1 | tail -n 1 | grep -oP '\d+\,?\d* (M|G)B/s' | awk '{printf "%s %s | ", $1, $2}' >> benchmark.md && \
    rm ./payload2.tar && \
    dd if=./payload.tar of=/dev/null bs=4M status=progress 2>&1 | tail -n 1 | grep -oP '\d+\,?\d* (M|G)B/s' | awk '{printf "%s %s |", $1, $2}' >> benchmark.md && \
    echo "" >> benchmark.md

#### LUKS
echo -n "| LUKS | " >> benchmark.md && \
    # set up
    dd if=/dev/zero of=./container.img bs=1M count=5000 && \
    dd if=/dev/random of=./keyfile bs=1024 count=4 && \
    sudo chmod 0400 ./keyfile && \
    sudo cryptsetup luksFormat --key-file ./keyfile --batch-mode ./container.img && \
    sudo cryptsetup luksOpen ./container.img my_luks --key-file ./keyfile && \
    sudo mkfs.ext4 /dev/mapper/my_luks && \
    mkdir ./luks-mount && \
    sudo mount /dev/mapper/my_luks ./luks-mount && \
    # benchmark
    cat ./payload.tar | sudo dd of=./luks-mount/payload.tar bs=4M status=progress 2>&1 | tail -n 1 | grep -oP '\d+\,?\d* (M|G)B/s' | awk '{printf "%s %s | ", $1, $2}' >> benchmark.md && \
    sudo dd if=./luks-mount/payload.tar of=/dev/null bs=4M status=progress 2>&1 | tail -n 1 | grep -oP '\d+\,?\d* (M|G)B/s' | awk '{printf "%s %s |", $1, $2}' >> benchmark.md && \
    # clean up
    sudo umount ./luks-mount && \
    sudo cryptsetup luksClose my_luks && \
    sudo rm -rf ./luks-mount ./keyfile ./container.img && \
    echo "" >> benchmark.md

#### ZFS
echo -n "| ZFS | " >> benchmark.md && \
    # set up
    dd if=/dev/zero of=./container.img bs=1M count=5000 && \
    dd if=/dev/random of=./keyfile bs=32 count=1 && \
    sudo chmod 0400 ./keyfile && \
    sudo zpool create mypool $PWD/container.img && \
    sudo zfs create -o encryption=on -o keyformat=raw -o keylocation=file://$PWD/keyfile mypool/encrypted_data && \
    # benchmark
    cat ./payload.tar | sudo dd of=/mypool/encrypted_data/payload.tar bs=4M status=progress 2>&1 | tail -n 1 | grep -oP '\d+\,?\d* (M|G)B/s' | awk '{printf "%s %s | ", $1, $2}' >> benchmark.md && \
    sudo dd if=/mypool/encrypted_data/payload.tar of=/dev/null bs=4M status=progress 2>&1 | tail -n 1 | grep -oP '\d+\,?\d* (M|G)B/s' | awk '{printf "%s %s |", $1, $2}' >> benchmark.md && \
    # clean up
    sudo zpool destroy mypool && \
    sudo rm -rf ./keyfile ./container.img && \
    echo "" >> benchmark.md

#### ecryptfs
echo -n "| ecryptfs | " >> benchmark.md && \
    # setup
    mkdir ./private_data ./encrypted_data && \
    echo "SecretPassphrase" > keyfile && \
    sudo chmod 0400 ./keyfile && \
    output=$(cat keyfile | ecryptfs-add-passphrase --fnek) && \
    SIG=$(echo "$output" | awk '/Inserted auth tok with sig/ {print $6}' | sed -n '1p' | tr -d '[]') && \
    FNEK_SIG=$(echo "$output" | awk '/Inserted auth tok with sig/ {print $6}' | sed -n '2p' | tr -d '[]') && \
    sudo mount -t ecryptfs ./private_data ./encrypted_data \
        -o ecryptfs_sig=$SIG,ecryptfs_fnek_sig=$FNEK_SIG,ecryptfs_enable_filename_crypto=y,ecryptfs_passthrough=n,ecryptfs_cipher=aes,ecryptfs_key_bytes=16,key=passphrase:passphrase_passwd=$(cat keyfile),ecryptfs_unlink_sigs,no_prompt && \
    # benchmark
    cat ./payload.tar | sudo dd of=./encrypted_data/payload.tar bs=4M status=progress 2>&1 | tail -n 1 | grep -oP '\d+\,?\d* (M|G)B/s' | awk '{printf "%s %s | ", $1, $2}' >> benchmark.md && \
    sudo dd if=./encrypted_data/payload.tar of=/dev/null bs=4M status=progress 2>&1 | tail -n 1 | grep -oP '\d+\,?\d* (M|G)B/s' | awk '{printf "%s %s |", $1, $2}' >> benchmark.md && \
    # cleanup
    sudo umount -l ./encrypted_data && \
    rm -rf ./private_data ./encrypted_data ./keyfile && \
    echo "" >> benchmark.md

#### fscrypt ext4
echo -n "| fscrypt | " >> benchmark.md && \
    # setup
    dd if=/dev/zero of=./container.img bs=1M count=5000 && \
    mkfs.ext4 ./container.img && \
    sudo losetup /dev/loop111 ./container.img && \
    sudo mkdir /mnt/fscrypt1 && \
    sudo mount /dev/loop111 /mnt/fscrypt1 && \
    sudo fscrypt setup --force --all-users /mnt/fscrypt1 && \
    sudo tune2fs -O encrypt "/dev/loop111" && \
    sudo mkdir /mnt/fscrypt1/my_encrypted_dir && \
    dd if=/dev/random of=./keyfile bs=32 count=1 && \
    sudo chmod 0400 ./keyfile && \
    sudo fscrypt encrypt /mnt/fscrypt1/my_encrypted_dir --key=./keyfile --quiet --name=mydir  && \
    # benchmark
    cat ./payload.tar | sudo dd of=/mnt/fscrypt1/my_encrypted_dir/payload.tar bs=4M status=progress 2>&1 | tail -n 1 | grep -oP '\d+\,?\d* (M|G)B/s' | awk '{printf "%s %s | ", $1, $2}' >> benchmark.md && \
    sudo dd if=/mnt/fscrypt1/my_encrypted_dir/payload.tar of=/dev/null bs=4M status=progress 2>&1 | tail -n 1 | grep -oP '\d+\,?\d* (M|G)B/s' | awk '{printf "%s %s |", $1, $2}' >> benchmark.md && \
    # cleanup
    sudo umount /mnt/fscrypt1/ && \
    sudo losetup -d /dev/loop111 && \
    sudo rm -rf /mnt/fscrypt1 ./container.img ./keyfile && \
    echo "" >> benchmark.md

#### Veracrypt
echo -n "| Veracrypt | " >> benchmark.md && \
    veracrypt --text --create ./container.hc \
        --size 5000M --password qwerty123 --encryption AES --hash SHA-512 \
        --filesystem ext4 --volume-type normal --pim 512 --keyfiles "" --random-source /dev/urandom && \
    sudo mkdir -p /mnt/veracrypt1 && \
    sudo veracrypt --text ./container.hc /mnt/veracrypt1 --password qwerty123 --pim 512 --protect-hidden=no --keyfiles "" && \
    # benchmark
    cat ./payload.tar | sudo dd of=/mnt/veracrypt1/payload.tar bs=4M status=progress 2>&1 | tail -n 1 | grep -oP '\d+\,?\d* (M|G)B/s' | awk '{printf "%s %s | ", $1, $2}' >> benchmark.md && \
    sudo dd if=/mnt/veracrypt1/payload.tar of=/dev/null bs=4M status=progress 2>&1 | tail -n 1 | grep -oP '\d+\,?\d* (M|G)B/s' | awk '{printf "%s %s |", $1, $2}' >> benchmark.md && \
    # cleanup
    sudo veracrypt -d /mnt/veracrypt1 && \
    sudo rm -rf /mnt/veracrypt1 ./container.hc && \
    echo "" >> benchmark.md