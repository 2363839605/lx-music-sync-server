FROM alpine AS base

FROM base AS builder
WORKDIR /source-code
COPY . .

RUN apk add --update \
    g++ \
    make \
    py3-pip \
    nodejs \
    npm

# 安装主项目依赖并构建
RUN npm ci && npm run build

# 安装 NeteaseCloudMusicApi 依赖
RUN cd NeteaseCloudMusicApi && npm ci && cd ..

# 重新安装主项目生产依赖
RUN rm -rf node_modules && npm ci --omit=dev

# 准备构建输出
RUN mkdir build-output \
  && mv server node_modules config.js index.js package.json NeteaseCloudMusicApi -t build-output


FROM base AS final
WORKDIR /server

RUN apk add --update --no-cache nodejs curl

COPY --from=builder ./source-code/build-output ./

# 创建必要的目录和文件
RUN mkdir -p /tmp \
    && echo "ANONYMOUS_TOKEN" > /tmp/anonymous_token \
    && chmod 644 /tmp/anonymous_token

VOLUME /server/data
ENV DATA_PATH '/server/data/data'
ENV LOG_PATH '/server/data/logs'

EXPOSE 9527
ENV NODE_ENV 'production'
ENV PORT 9527
ENV BIND_IP '0.0.0.0'
# ENV PROXY_HEADER 'x-real-ip'
# ENV SERVER_NAME 'My Sync Server'
# ENV MAX_SNAPSHOT_NUM '10'
# ENV LIST_ADD_MUSIC_LOCATION_TYPE 'top'
# ENV LX_USER_user1 '123.123'
# ENV LX_USER_user2 '{ "password": "123.456", "maxSnapshotNum": 10, "list.addMusicLocationType": "top" }'
# ENV CONFIG_PATH '/server/config.js'
# ENV LOG_PATH '/server/logs'
# ENV DATA_PATH '/server/data'

# 添加健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:9527/hello || exit 1

CMD [ "node", "index.js" ]
