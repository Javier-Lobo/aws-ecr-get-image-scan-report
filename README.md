# aws-ecr-get-image-scan-report
Script para descargar el json de los informes de vulnerabilidades de imágenes en AWS ECR y generar un informe en Markdown.

El script está escrito para que funcione en macOS y utilice whiptail para mostrar un entorno gráfico noventero.

## ¿Qué hace esto?
En tiempo de ejecución, pregunta por el repositorio que contiene la imagen de la que se va a descargar el informe.

![repo-name.png](readme-assets/repo-name.png)

Después, lee los profiles de AWS existentes en ~/.aws/config y los presenta en una lista para elegir el que se necesite.

![aws-profile.png](readme-assets/aws-profile.png)

A continuación, busca la última imagen almacenada en el repositorio dado y descarga su informe en `json`, y lo parsea.

![downloading.png](readme-assets/downloading.png)

Finalmente, lo guarda en ~/Downloads con el nombre del repositorio indicado, junto con su identificador y la fecha dentro del informe.

![success.png](readme-assets/success.png)

El resultado será algo como esto:

![report.png](readme-assets/report.png)

Lo de enviarle el informe a tus developers y darles con un palo para que arreglen las vulnerabilidades, ya es un proceso más manual ;)