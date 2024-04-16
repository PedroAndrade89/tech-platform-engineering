FROM node:alpine3.18

WORKDIR /app

ENV PATH /app/node_modules/.bin:$PATH

# install app dependencies
COPY package.json ./
COPY package-lock.json ./
RUN npm install --silent
#RUN npm install react-scripts@3.4.1 -g --silent

EXPOSE 3000
# add app
COPY . ./
# start app
CMD ["npm", "start"]