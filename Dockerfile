FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update && \
    apt-get install -y curl && \
    apt-get clean

RUN curl -sSL https://install.python-poetry.org | python3 -

# Add Poetry to the PATH
ENV PATH="/root/.local/bin:$PATH"
ENV PORT=5000

# Copy poetry files first to utilize docker caching
COPY pyproject.toml /app/

# Install project dependencies
RUN poetry config virtualenvs.create false \
    && poetry install --no-root --only main

# Copy the rest of the application code
COPY ./weather_app/ /app

# Expose the port the app runs on
EXPOSE 5000

# Define the command to run the application
CMD ["flask", "run", "--host=0.0.0.0"]

