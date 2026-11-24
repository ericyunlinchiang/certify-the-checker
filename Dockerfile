# Same tools as the results table: Ubuntu 24.04, gcc 13, clang 18, cppcheck 2.13.
# Build:  docker build -t certify-the-checker .
# Run:    docker run --rm certify-the-checker            (prints the table and checks it)
FROM ubuntu:24.04
RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc clang cppcheck python3 bash ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /work
COPY . /work
CMD ["tools/run_all.sh", "--check"]
