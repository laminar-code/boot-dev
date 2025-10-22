FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

ENV LANG=en_US.UTF-8
ENV LANGUAGE="en_US"

ARG OCI_TITLE_LABEL=org.opencontainers.image.title
ARG OCI_TITLE_VALUE=ERROR
ARG OCI_DESCRIPTION_LABEL=org.opencontainers.image.description
ARG OCI_DESCRIPTION_VALUE=ERROR
ARG OCI_CREATED_LABEL=org.opencontainers.image.created
ARG OCI_CREATED_VALUE=ERROR
ARG OCI_AUTHORS_LABEL=org.opencontainers.image.authors
ARG OCI_AUTHORS_VALUE=ERROR
ARG OCI_VENDOR_LABEL=org.opencontainers.image.vendor
ARG OCI_VENDOR_VALUE=ERROR
ARG OCI_LICENSE_LABEL=org.opencontainers.image.licenses
ARG OCI_LICENSE_VALUE=ERROR
ARG OCI_SOURCE_LABEL=org.opencontainers.image.source
ARG OCI_SOURCE_VALUE=ERROR
ARG OCI_URL_LABEL=org.opencontainers.image.url
ARG OCI_URL_VALUE=ERROR
ARG OCI_DOCS_LABEL=org.opencontainers.image.documentation
ARG OCI_DOCS_VALUE=ERROR
ARG OCI_VERSION_LABEL=org.opencontainers.image.version
ARG OCI_VERSION_VALUE=ERROR
ARG OCI_REVISION_LABEL=org.opencontainers.image.revision
ARG OCI_REVISION_VALUE=ERROR
ARG OCI_REFNAME_LABEL=org.opencontainers.image.ref.name
ARG OCI_REFNAME_VALUE=ERROR

# hadolint ignore=DL3048
LABEL ${OCI_TITLE_LABEL}=${OCI_TITLE_VALUE}
# hadolint ignore=DL3048
LABEL ${OCI_DESCRIPTION_LABEL}=${OCI_DESCRIPTION_VALUE}
# hadolint ignore=DL3048
LABEL ${OCI_CREATED_LABEL}=${OCI_CREATED_VALUE}
# hadolint ignore=DL3048
LABEL ${OCI_AUTHORS_LABEL}=${OCI_AUTHORS_VALUE}
# hadolint ignore=DL3048
LABEL ${OCI_VENDOR_LABEL}=${OCI_VENDOR_VALUE}
# hadolint ignore=DL3048
LABEL ${OCI_LICENSE_LABEL}=${OCI_LICENSE_VALUE}
# hadolint ignore=DL3048
LABEL ${OCI_SOURCE_LABEL}=${OCI_SOURCE_VALUE}
# hadolint ignore=DL3048
LABEL ${OCI_URL_LABEL}=${OCI_URL_VALUE}
# hadolint ignore=DL3048
LABEL ${OCI_DOCS_LABEL}=${OCI_DOCS_VALUE}
# hadolint ignore=DL3048
LABEL ${OCI_VERSION_LABEL}=${OCI_VERSION_VALUE}
# hadolint ignore=DL3048
LABEL ${OCI_REVISION_LABEL}=${OCI_REVISION_VALUE}
# hadolint ignore=DL3048
LABEL ${OCI_REFNAME_LABEL}=${OCI_REFNAME_VALUE}

# Configure certs
COPY .build/certs/.placeholder .build/certs/*.crt /usr/local/share/ca-certificates/

# Update certs then update apt package lists and upgrade current packages
# Install nala for parallel downloads and updates
# then install base level required packages
# Configure locales
RUN apt-get -yqq update \
  && apt-get -yqq upgrade \
  && apt-get -yqq install nala=0.15.1 --no-install-recommends \
  && nala install -y locales sudo make curl git slirp4netns uidmap buildah xz-utils nano gcc \
  && nala clean --lists \
  && rm -rf /var/lib/apt/lists/* \
  && update-ca-certificates \
  && locale-gen en_US \
  && locale-gen en_US.UTF-8 \
  && dpkg-reconfigure locales \
  && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \
  && update-locale LANG="en_US.UTF-8" LANGUAGE="en_US"

# Startup at the command line
CMD ["/usr/bin/bash"]

