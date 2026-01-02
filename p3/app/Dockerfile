FROM nginx:stable-alpine
LABEL maintainer="kitako"

WORKDIR /usr/share/nginx/html

# Remove default content
RUN rm -rf ./*

COPY . /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

