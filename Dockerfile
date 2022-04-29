FROM python:3 as builder
COPY requirements.txt .
RUN pip3 install --user -r requirements.txt
FROM python:3-slim
RUN apt update -y \
    && apt install -y --no-install-recommends genisoimage make rsync curl vim \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /root/.local /usr/local
COPY --from=mikefarah/yq:4.24.5 /usr/bin/yq /usr/local/bin
COPY --from=vmware/govc:v0.27.2 /govc /usr/local/bin
WORKDIR /ansible
COPY env.yml Makefile tools.sh playbook.yml .
