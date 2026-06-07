FROM commonlispbr/roswell:latest
RUN apt update && apt install libev4 wget file make -y
WORKDIR /cl-bbs
RUN ln -s /cl-bbs /root/.roswell/local-projects/cl-bbs
COPY ./cl-bbs.asd cl-bbs.asd
COPY ./src src
COPY ./tests tests
COPY ./roswell roswell

ARG APP_VERSION
ENV APP_VERSION=$APP_VERSION
RUN ros build roswell/cl-bbs-server.ros
EXPOSE 8080
ENTRYPOINT ["/cl-bbs/roswell/cl-bbs-server"]