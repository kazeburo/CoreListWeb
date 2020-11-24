FROM perl:5.32
RUN mkdir -p /opt/app
RUN cpanm -n Carton
COPY ./cpanfile /opt/app/cpanfile
COPY ./cpanfile.snapshot /opt/app/cpanfile.snapshot
WORKDIR /opt/app
RUN carton install --deployment
EXPOSE 5000
COPY . /opt/app
RUN mkdir -p /opt/app/tmp
CMD carton exec -- ./server.pl

