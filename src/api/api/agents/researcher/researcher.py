import json
import os
import sys

from promptflow.tracing import trace
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import (
    PromptAgentDefinition,
    WebSearchTool,
)

from dotenv import load_dotenv

load_dotenv()

FOUNDRY_PROJECT_ENDPOINT = os.environ["FOUNDRY_PROJECT_ENDPOINT"]
MODEL_DEPLOYMENT = os.getenv("AZURE_OPENAI_35_TURBO_DEPLOYMENT_NAME", "gpt-4o-mini")


def _build_research_query(request: str, instructions: str, feedback: str = "") -> str:
    """Build a research query prompt from the request, instructions, and feedback."""
    parts = [
        "You are an expert researcher helping a writer create an article.",
        "Search the web thoroughly for the following topic. Include general information,",
        "notable entities (people, places, things), and recent news when relevant.",
        "",
        f"Topic: {request}",
        f"Instructions: {instructions}",
    ]
    if feedback and feedback != "No Feedback":
        parts.append(f"Previous feedback to address: {feedback}")
    return "\n".join(parts)


@trace
def execute(request: str, instructions: str, feedback: str = ""):
    """Perform web research using the Foundry Agent Service web search tool."""
    project = AIProjectClient(
        endpoint=FOUNDRY_PROJECT_ENDPOINT,
        credential=DefaultAzureCredential(),
    )
    openai = project.get_openai_client()

    agent = project.agents.create_version(
        agent_name="researcher-agent",
        definition=PromptAgentDefinition(
            model=MODEL_DEPLOYMENT,
            instructions=(
                "You are an expert web researcher. Search the web to find comprehensive "
                "information about the given topic. Include facts, notable entities "
                "(people, places, things), and recent news. Provide detailed findings "
                "with source URLs cited inline."
            ),
            tools=[WebSearchTool()],
        ),
        description="Research agent for creative writing",
    )

    try:
        query = _build_research_query(request, instructions, feedback)

        response = openai.responses.create(
            input=query,
            tool_choice="required",
            extra_body={"agent_reference": {"name": agent.name, "type": "agent_reference"}},
        )

        summary = response.output_text or ""
        citations = []
        for item in response.output:
            if hasattr(item, "content"):
                for content_block in item.content:
                    if hasattr(content_block, "annotations"):
                        for annotation in content_block.annotations:
                            if hasattr(annotation, "url") and annotation.url:
                                citations.append({
                                    "url": annotation.url,
                                    "title": getattr(annotation, "title", annotation.url),
                                })

        return {
            "summary": summary,
            "citations": citations,
        }
    finally:
        project.agents.delete_version(
            agent_name=agent.name, agent_version=agent.version
        )


def research(request, instructions, feedback: str = ""):
    return execute(request=request, instructions=instructions, feedback=feedback)


if __name__ == "__main__":
    context = sys.argv[1]
    instructions = sys.argv[2]

    result = execute(request=context, instructions=instructions, feedback="")
    print(json.dumps(result, indent=2))
