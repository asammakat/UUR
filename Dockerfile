# Dockerfile

# Python arm64 runtime as a parent image for RPI deployment
FROM --platform=linux/arm64/v8 arm64v8/python:3.10

# This is supposed to stop truncated output when crashes happen
ENV PYTHONUNBUFFERED=1

# Allow Docker to cache installed dependencies between builds
COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Mount the application code to the image
COPY . code
WORKDIR /code

EXPOSE 8000

# Run the server
ENTRYPOINT ["python", "./manage.py"]
CMD ["runserver", "0.0.0.0:8000"]
