---
layout: post
title: Building a Production-Ready AI Agent with Google ADK, Gemini 3, and MCP on Cloud Run
categories: [GCP, ADK, Gemini 3, MCP]
excerpt: "In the rapidly evolving world of AI agents, the Model Context Protocol (MCP) has emerged as a game-changer for standardizing how AI models connect to external tools. This article will help you walk through steps to build something special: a production-ready AI agent that doesn't just run tools locally, but connects to a remote MCP server deployed on Google Cloud Run."
image: assets/img/Gemini_MCP_ADK_Cloudrun.png
---

In the rapidly evolving world of AI agents, the **Model Context Protocol (MCP)** has emerged as a game-changer for standardizing how AI models connect to external tools. This article will help you walk through steps to build something special: a production-ready AI agent that doesn't just run tools locally, but connects to a **remote MCP server deployed on Google Cloud Run**.

We'll use the **Google Agent Development Kit (ADK)** to build a beautiful web-based chat interface powered by **Gemini 3**, communicating securely over HTTPS with our serverless weather tools.

## The Architecture

Before we dive into code, let's look at what we're building.

![image](assets/img/mcp-cloudrun.png)


**Why this matters?**
*   **Scalability**: Your tools run on serverless infrastructure (Cloud Run) that can scales to zero.
*   **Security**: API keys for tools are stored in Google Secret Manager, not on the client.
*   **Reusability**: One MCP server can serve multiple agents or users.


## Prerequisites

*   [Google Cloud console](https://console.cloud.google.com/) (for Cloud Run)
*   [Google AI Studio](https://aistudio.google.com/) (for Gemini API Key)
*   [WeatherAPI.com](https://www.weatherapi.com/) ( for weather API Key, free tier is fine)
*   Python 3.12+ and `uv` (modern Python package manager)

Before we begin, clone the source code from [this repository](https://github.com/truongnh1992/mcp-on-cloudrun) to follow along.

```sh
git clone https://github.com/truongnh1992/mcp-on-cloudrun.git
```

## Part 1: The MCP Server

Let's start by building the backend MCP server. We'll use `fastmcp` to define our tools and wrap them in an application, which allows us to expose the tools via HTTP endpoints that can be accessed remotely over the internet.

### 1. Define the Tools (`weather.py`)

First, we define our weather capabilities using the `@mcp.tool()` decorator.

```python
from mcp.server.fastmcp import FastMCP
import httpx

mcp = FastMCP("weather")

@mcp.tool()
async def get_current_weather(city: str) -> str:
    """Get current weather conditions for a city."""
    # ... (implementation calling WeatherAPI) ...
    return f"The weather in {city} is {temp}°C and {condition}."

@mcp.tool()
async def get_forecast(city: str, days: int = 3) -> str:
    """Get weather forecast for a city."""
    # ... (implementation) ...
```

### 2. Create the HTTP Handler

To make this accessible remotely, we implement a JSON-RPC 2.0 handler. This allows our agent to send `tools/call` requests via standard HTTPS POST.

```python
# mcp-server/weather.py

async def mcp_handler(request):
    data = await request.json()
    method = data.get("method")
    
    if method == "tools/call":
        result = await handle_tool_call(data) # Execute the tool
        return JSONResponse(result)
        
    # Handle 'initialize' and 'tools/list' similarly...

app = Starlette(routes=[
    Route('/', mcp_handler, methods=['POST']),
])
```

### 3. Deploy to Google Cloud Run

We containerize our server with Docker and deploy it. Using Cloud Run means we don't pay for a server when no one is asking about the weather!

```bash
# mcp-server/deploy.sh
gcloud run deploy weather-mcp-server \
    --source . \
    --region asia-southeast1 \
    --allow-unauthenticated \
    --set-secrets WEATHERAPI_KEY=weatherapi-key:latest
```

Once deployed, you get a secure URL: `https://weather-mcp-server-xyz.run.app`.


## Part 2: The AI Agent (Google ADK)

Now for the client side. We use **Google ADK** which gives us a professional web interface and easy integration with Gemini.

### 1. Connect to the Remote Server

Instead of importing python functions directly, we configure the ADK agent to talk to our Cloud Run URL.

```python
# mcp-client/weather_agent/agent.py

from google.adk import Agent
from google.adk.tools.mcp_tool.mcp_toolset import McpToolset, StreamableHTTPConnectionParams

# Your Cloud Run URL
MCP_SERVER_URL = "https://weather-mcp-server-xyz.run.app"

connection_params = StreamableHTTPConnectionParams(
    url=MCP_SERVER_URL,
    timeout=30.0, # Give Cloud Run time to wake up (cold start)
)

weather_tools = McpToolset(connection_params=connection_params)

root_agent = Agent(
    name="weather_agent",
    model="gemini-3-pro-preview"
    tools=[weather_tools],
)
```

### 2. Run the Agent

With `uv`, starting the agent is a breeze:

```bash
cd mcp-client
uv run adk web
```

This launches the ADK interface at `http://localhost:8000`.


## Seeing it in Action

1.  Open your browser to `http://localhost:8000`.
2.  Select **weather_agent**.
3.  Ask: *"What's the weather like in Hanoi right now?"*

**What happens behind the scenes:**

1> **Gemini** analyzes your request and decides to call `get_current_weather("Hanoi")`.

2> **ADK** sends a JSON-RPC request to your **Cloud Run** endpoint.

3> Your server wakes up, calls **WeatherAPI**, and returns the data.

4> **Gemini** receives the raw data (Temp: 18°C, Humidity: 45%) and answers you naturally: *"It's currently a pleasant 18°C in Hanoi with clear skies..."*

There are four key players here: the **User**, our **Agent** (which acts as the MCP Client), the **Model** (the 'brain', in this case, Gemini), and the **Tools** (exposed via an MCP Server).


![image](assets/img/mcp-workflows.png)

The process happens in four steps:

- **Step 1**: The User prompts the agent. This is the starting point. The user asks a question or gives a command that requires external information, like *"What's the weather in Hanoi?"*
- **Step 2**: The Agent sends this prompt to the Model. The agent itself doesn't know What's the weather in Hanoi?; its job is to orchestrate. It sends the user's request, along with a list of available tools, to the Gemini model. The model then uses its reasoning and [function-calling](https://ai.google.dev/gemini-api/docs/function-calling?example=weather) capabilities to determine which tool is needed and what parameters to use. For example, it would decide: "I need the `get_current_weather` tool with `city: Hanoi`." It then sends this structured command back to the agent.
- **Step 3**: The Agent calls the corresponding tool. Now that the agent has its instructions from the model, it acts. As an MCP Client, it makes a standardized call to the MCP Server that hosts the `get_current_weather` function. It executes the call.
- **Step 4**: The Model interprets the output. The tool does its job and returns raw data. This isn't a very human-friendly response. So, the agent sends this data back to the Gemini model one last time. The model's final job is to interpret that raw data and generate a natural, conversational response for the user.

So, to summarize: The **Model** is the thinker, the **Agent** is the doer, and **MCP** is the standard protocol that allows them to communicate with the tools reliably

## Key Takeaways

*   **Remote MCP is powerful**: You can build a library of shared tools hosted on the cloud, accessible by any agent with the right credentials.
*   **Google ADK simplifies UI**: You don't need to build a frontend from scratch; ADK provides a chat interface with streaming support out of the box.
*   **Cloud Run is perfect for tools**: Serverless is the ideal home for sporadic tool usage-efficient, cost-effective, and scalable.


Happy coding! 🚀