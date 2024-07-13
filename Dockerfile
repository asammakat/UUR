# Dockerfile

# Official Python runtime as a parent image
FROM python:3.10

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
