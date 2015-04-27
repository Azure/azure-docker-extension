FROM golang
RUN  useradd azureuser

COPY testdata/lsb-release lsb-release
RUN  mv lsb-release /etc/lsb-release
COPY testdata/ovf-env.xml /var/lib/waagent/ovf-env.xml

COPY testdata/HandlerEnvironment.json HandlerEnvironment.json
RUN  mv HandlerEnvironment.json ../HandlerEnvironment.json
COPY testdata/Extension /var/lib/waagent/Extension

ADD src src
RUN go build -o a.out docker-extension
ENTRYPOINT ["./a.out"]
