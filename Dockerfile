#
# Command to build the image:
#   sudo docker build -t sd:0.0.1 .
#
# Example command to start the container (better to use Docker Compose):
# sudo docker run -t -i --init -v /opt/models:/models -p 80:80 -v .:/current sd:0.0.1
 
# Using Ubuntu 22.04 as our base image
ARG UBUNTU_VERSION=22.04
FROM ubuntu:$UBUNTU_VERSION AS build

# Install build tools
RUN apt-get update && apt-get install -y build-essential git cmake

# Download and build XNNPack
WORKDIR /
RUN git clone https://github.com/google/XNNPACK.git \
    && cd XNNPACK \
    && git checkout 579de32260742a24166ecd13213d2e60af862675 \
    && mkdir build \
    && cd build \
    && cmake -DXNNPACK_BUILD_TESTS=OFF -DXNNPACK_BUILD_BENCHMARKS=OFF .. \
    && cmake --build . --config Release

# Download and build OnnxStream
WORKDIR OnnxStream
COPY src .
RUN mkdir build \
    && cd build \
    && cmake -DMAX_SPEED=ON -DOS_LLM=OFF -DOS_CUDA=OFF -DXNNPACK_DIR=/XNNPACK .. \
    && cmake --build . --config Release

# Runtime stage
FROM ubuntu:$UBUNTU_VERSION AS runtime

# Upgrade system, install nginx, php-fpm, curl, and git in our environment
RUN apt-get update && apt-get -y upgrade && DEBIAN_FRONTEND=noninteractive apt-get -y install \
    git nginx php8.1-fpm curl

# Grab our sd binary
COPY --from=build /OnnxStream/build/sd /sd

#GUI Stuff

# Download OnnxStreamGui and copy it to nginx's webroot

RUN git clone https://github.com/eiddor/OnnxStreamGui \
    && cp -Rp OnnxStreamGui/Web/* /var/www/html/.

# Override nginx's default config to enable PHP FPM (I should change this to a sed command eventually)
COPY ./default /etc/nginx/sites-available/default

# Copy Entrypoint script
COPY ./docker-entrypoint.sh /docker-entrypoint.sh

# Expose port 80 for nginx.
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

ENTRYPOINT ["/docker-entrypoint.sh"]
