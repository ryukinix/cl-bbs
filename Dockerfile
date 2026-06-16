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
ARG APP_COMMIT_HASH
ENV APP_COMMIT_HASH=$APP_COMMIT_HASH
ENV SBBS_DATADIR=/cl-bbs/data/
ENV SBBS_STATIC_DIR=/cl-bbs/src/static/
ENV SBBS_INDEX_FILE=/cl-bbs/src/static/index.html
RUN ros build roswell/cl-bbs-server.ros
EXPOSE 8222
ENTRYPOINT ["/cl-bbs/roswell/cl-bbs-server"]