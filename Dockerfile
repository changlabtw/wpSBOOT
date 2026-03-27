FROM continuumio/miniconda3:latest

# Install C++ build tools for compiling wei_seqboot
RUN apt-get update && apt-get install -y --no-install-recommends \
        g++ make \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/wpsboot

# Copy repository contents
COPY . .

# Install pipeline dependencies (t_coffee, raxml-ng, perl-bioperl, python)
RUN conda env update -n base --file environment.yml \
    && conda clean -afy

# Compile wei_seqboot from source; output goes to bin/ via makefile
RUN cd src && make && cd ..

# Point bin/ entries at the conda-installed Linux binaries
RUN ln -sf /opt/conda/bin/t_coffee  bin/t_coffee \
    && ln -sf /opt/conda/bin/raxml-ng bin/raxml-ng

# Ensure all scripts are executable
RUN chmod +x scripts/wpsboot.sh scripts/step*.sh scripts/*.pl test.sh

ENTRYPOINT ["bash", "/opt/wpsboot/scripts/wpsboot.sh"]
