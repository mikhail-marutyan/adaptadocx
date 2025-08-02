FROM node:20-slim

ARG TARGETPLATFORM=linux/amd64
ARG VALE_VERSION=2.29.4
ARG HTMLTEST_VERSION=0.17.0
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    git make curl unzip \
    python3 python3-pip \
    ruby ruby-dev asciidoctor pandoc \
    texlive-latex-base texlive-fonts-recommended texlive-lang-cyrillic \
    fonts-dejavu-core \
    wkhtmltopdf ghostscript librsvg2-bin \
    && rm -rf /var/lib/apt/lists/*

RUN gem install asciidoctor-pdf prawn-svg --no-document

# Install Vale and htmltest binaries
RUN set -e; \
    arch_vale="Linux_64-bit"; \
    arch_html="linux_amd64"; \
    if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
      arch_vale="Linux_arm64"; arch_html="linux_arm64"; \
    fi; \
    curl -fsSL -o vale.tar.gz "https://github.com/errata-ai/vale/releases/download/v${VALE_VERSION}/vale_${VALE_VERSION}_${arch_vale}.tar.gz" && \
    tar -xzf vale.tar.gz && mv vale /usr/local/bin/ && rm vale.tar.gz && \
    curl -fsSL -o htmltest.tar.gz "https://github.com/wjdp/htmltest/releases/download/v${HTMLTEST_VERSION}/htmltest_${HTMLTEST_VERSION}_${arch_html}.tar.gz" && \
    tar -xzf htmltest.tar.gz && mv htmltest /usr/local/bin/ && rm htmltest.tar.gz

WORKDIR /work

COPY package*.json ./
RUN npm ci --no-audit --prefer-offline

COPY . .

CMD ["bash"]
