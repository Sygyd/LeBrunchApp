FROM node:16-alpine

WORKDIR /usr/src/app

# Comprobar si el directorio tiene un error de ortografía 
# En caso que el directorio se llame "sevidor" (con error) mantenerlo así
# Si no, cambiarlo a "servidor" (forma correcta)
# Copiar los archivos de dependencias primero
COPY sevidor/package*.json ./

# Instalar dependencias
RUN npm install

# Copiar el resto del código
COPY sevidor/ ./

# Crear directorio para las imágenes subidas
RUN mkdir -p uploads && chmod 777 uploads

# Establecer variables de entorno
ENV NODE_SERVER_IP=0.0.0.0
ENV NODE_SERVER_PORT=3000
ENV DB_HOST=db
ENV DB_PORT=5432
ENV DB_USER=postgres
ENV DB_PASSWORD=monito
ENV DB_NAME=postgres

# Exponer el puerto
EXPOSE 3000

# Comando para ejecutar la aplicación (corregido)
CMD ["node", "servidor.js"]
