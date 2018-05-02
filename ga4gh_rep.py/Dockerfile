## mokaguys/ga4gh_rep.py:v1.0
## Builds docker image for ga4gh reporting tool which produces HTML summary report based on output from Illumina hap.py
## See https://github.com/ga4gh/benchmarking-tools/tree/master/reporting/basic
## Example usage at https://hub.docker.com/r/mokaguys/ga4gh_rep.py/

# Use miniconda as parent image
FROM continuumio/miniconda:latest

# Set the working directory to /app
WORKDIR /app

# Clone GA4GH benchmarking repo
RUN git clone https://github.com/ga4gh/benchmarking-tools.git

# Install required python packages
RUN pip install -r ./benchmarking-tools/reporting/basic/requirements.txt

# Run rep.py when the docker container is run
ENTRYPOINT [ "python", "./benchmarking-tools/reporting/basic/bin/rep.py" ]

# Default parameter for rep.py if no paramters supplied by user
CMD [ "-h" ]