---
layout: post
title: Leveraging Serverless App Deployment with Cloud Run and Gemini - A Beginner’s Guide
categories: [GCP, Serverless, Gemini, Vertex AI]
excerpt: "Imagine you’re building a fantastic new application, perhaps a chatbot that helps users write better content, or an AI-powered image generator. You want to get it up and running quickly, without the headache of managing servers and infrastructure. Enter Cloud Run and Gemini!"
image: /assets/img/Gemini.png
comments: false
---

**Imagine** you’re building a fantastic new application, perhaps a chatbot that helps users write better content, or an AI-powered image generator. You want to get it up and running quickly, without the headache of managing servers and infrastructure. **Enter Cloud Run and Gemini!**

Cloud Run is Google Cloud’s serverless platform that lets you deploy containerized applications without managing any infrastructure. Gemini, Google’s powerful large language model, offers incredible AI capabilities. By combining these two, you can create a powerful, scalable, and cost-effective application with the power of AI.

This guide will take you through the journey of building a serverless app powered by Gemini on Cloud Run. I’ll cover the essentials from setting up your development environment to deploying your application. Let’s dive in!

<img src="/assets/img/Gemini.png">

## Why Choose Serverless and Gemini?

**Serverless** offers numerous advantages for developers:

- **No Server Management**: Forget about managing servers, patching, or scaling. Cloud Run takes care of everything for you.
- **Auto-Scaling**: Your application automatically scales up or down based on demand, ensuring optimal performance and cost efficiency.
- **Focus on Development**: Spend less time on infrastructure and more time building awesome features.

**Gemini** unlocks incredible AI capabilities for your application:

- **Natural Language Understanding**: Gemini understands and responds to human language, making your app more intuitive and engaging.
- **Content Generation**: Generate creative content, write summaries, translate languages, and much more.
- **Code Generation**: Gemini can even help you write code for your application, saving you time and effort.

The perfect combination? Cloud Run’s serverless environment allows you to deploy and manage your Gemini-powered application effortlessly, while Gemini adds the power of AI to your creation.

## Setting Up Your Development Environment

**First things first**: You’ll need a Google Cloud account and the necessary tools to develop and deploy your serverless application.

1. **Google Cloud Account**: If you don’t already have one, sign up for a free trial at https://cloud.google.com/.
2. **Cloud SDK**: Install the Google Cloud SDK to interact with Cloud Run and other GCP services. Find instructions on https://cloud.google.com/sdk/.
3. **Code Editor**: Choose your favorite code editor, such as VS Code, IntelliJ IDEA, PyCharm, or even vi/vim 😅
4. **Containerization**: You’ll be deploying your application as a container. Familiarize yourself with Docker or other containerization tools.

## Building a Gemini-Powered Serverless App

Let’s create a simple example: A serverless AI application powered by Gemini.

**1. Develop Your Code**: Using your chosen code editor, create a simple serverless function using a framework like Flask (Python) or Express.js (JavaScript). This function will:
   - Receive user input.
   - Send the input to Gemini using the Vertex AI API.
   - Receive Gemini’s response and format it for the user.
  
```python
import base64
from flask import Flask, render_template, request
import vertexai
import markdown
from vertexai.generative_models import GenerativeModel
import vertexai.preview.generative_models as generative_models

app = Flask(__name__)

vertexai.init(project="YOUR-PROJECT-ID", location="YOUR-REGION")
model = GenerativeModel("gemini-1.5-pro-001")

generation_config = {
    "max_output_tokens": 8192,
    "temperature": 1,
    "top_p": 0.95,
}

safety_settings = {
    generative_models.HarmCategory.HARM_CATEGORY_HATE_SPEECH: generative_models.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
    generative_models.HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT: generative_models.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
    generative_models.HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT: generative_models.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
    generative_models.HarmCategory.HARM_CATEGORY_HARASSMENT: generative_models.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
}

@app.route("/", methods=["GET", "POST"])
def index():
    response_text = ""
    if request.method == "POST":
        prompt = request.form["prompt"]
        response = model.generate_content(prompt, generation_config=generation_config, safety_settings=safety_settings)
        response_text = markdown.markdown(response.text)  # Convert response to markdown
    return render_template("index-with-css.html", response_text=response_text)


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=8080)
```
You can find the sample source code in this repository [https://github.com/truongnh1992/serverless-app-gemini](https://github.com/truongnh1992/serverless-app-gemini)

**2. Containerize Your App**: Build a Dockerfile to package your code and dependencies into a container image.
    
```Dockerfile
# Python image to use.
FROM python:3.9-slim-buster

# Install system-level dependencies for grpcio
RUN apt-get update && apt-get install -y \
    build-essential \
    libssl-dev \
    libffi-dev

# Set the working directory to /app
WORKDIR /app

# copy the requirements file used for dependencies
COPY requirements.txt .

# Install any needed packages specified in requirements.txt
RUN pip install --trusted-host pypi.python.org -r requirements.txt

# Copy the rest of the working directory contents into the container at /app
COPY . .

# Run app.py when the container launches
ENTRYPOINT ["python", "gemini-app.py"]
```
**3. Build Your Container**: Use the following command to build your docker image.

```bash
docker build -t your-image-name .
```
## Deploying to Cloud Run
Time to launch your serverless AI app into the world!

**Deploy Your Container**: Use the gcloud command-line tool to deploy your container image to Cloud Run.

```
gcloud run deploy hello-gemini --image your-image-name --region your-region
```

For example, in my case:
```bash
❯ gcloud run deploy hello-gemini --image gcr.io/my-project/hello-gemini:v3 --region asia-southeast1
Deploying container to Cloud Run service [hello-gemini] in project [my-project] region [asia-southeast1]
✓ Deploying... Done.
  ✓ Creating Revision...
  ✓ Routing traffic...
Done.
Service [hello-gemini] revision [hello-gemini-00002-84x] has been deployed and is serving 100 percent of traffic.
Service URL: https://hello-gemini-oze7nwnjba-as.a.run.app
```

**Access Your App**: Cloud Run automatically provides a unique URL to access your deployed application. You can now interact with your Gemini-powered chatbot!

The demo:

<iframe width="700" height="400" src="https://www.youtube.com/embed/WVJWY7iVISg?si=R2F3JAGEphoHKuPe" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

Going Further:

- **Scaling**: As your application gains popularity, Cloud Run automatically scales to handle increased traffic.
- **Monitoring**: Use Google Cloud’s monitoring tools to track performance and identify issues.
- **Security**: Implement security best practices to ensure your application and user data are protected.

**You’ve successfully built a serverless application powered by Gemini!** This example is just the beginning. Explore the vast capabilities of Gemini and Cloud Run to create even more powerful and innovative applications.

## A nifty trick

If your code is in Go, Node.js, Python, Java, Kotlin, Groovy, Scala, .NET, Ruby, or PHP, you can skip the Dockerfile and image building — Cloud Run deploys directly from your source code.

```
gcloud run deploy SERVICE --source .
```

Happy coding!
