find . -name "*.proto" -print0 | xargs -0 -I {} protoc --descriptor_set_out {}.pb {}
