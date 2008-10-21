#!/bin/bash

if [ -z $1 ]; then
    echo "Usage: $0 <install path>"
    exit 0
else
    echo "Installing to $1"
fi

mkdir -p $1/bin
mkdir -p $1/share/rrssdl
cp *.rb rrssdl rrssdlrc $1/share/rrssdl
cat > $1/bin/rrssdl <<EOF
#!/bin/bash

pushd $1/share/rrssdl
./rrssdl
popd
EOF

echo "Installation Complete"
