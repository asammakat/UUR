A simple REST api built with Django for fetching quotes from the inspirational work "The You You Are" by Dr Ricken Lazlo Hale, PhD.

## Docker image
Available in a public repo asammakia/uur-container. The most recent version is 1.0.6.

## Minikube deploy
The k8s files in this repo are based off of this [excellent guide](https://www.youtube.com/watch?v=05BwSZ9elYI&ab_channel=Djangoroad).

### Secrets
Before deploying two secrets files need to be added:

deploy/application/secrets.yaml
```
apiVersion: v1
kind: Secret
metadata:
  name: uur-secrets
type: Opaque
data:
  SECRET_KEY: <base64 encode your secret key>
  DB_USERNAME: <base64 encode your db username> # this will probably be 'postgres'
  DB_PASSWORD: <base64 encode your db password>
```

deploy/database/secrets.yaml
```
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secrets
type: Opaque
data:
  database: <base64 encode your database name> # I used UUR, this must match the name used in deploy/application/configmap.yaml
  username: <base 64 encode your db username> # this will probably be 'postgres'
  password: <base64 encode your db password>
```
### Deploy Database
Deploy the database files
```
kubectl apply -f deploy/database/secret.yaml
kubectl apply -f deploy/database/storage.yaml
kubectl apply -f deploy/database/deployment.yaml
kubectl apply -f deploy/database/service.yaml

```

### Update Application Config Map
Get the cluster ip of the postgres service and add it to the `DB_HOST` data field of `deploy/application/configmap`
```
kubectl get service
```

### Deploy Application
Deploy the application files
```
kubectl apply -f deploy/application/configmap.yaml
kubectl apply -f deploy/application/secret.yaml.yaml
kubectl apply -f deploy/application/nginxconfig.yaml
kubectl apply -f deploy/application/deployment.yaml
kubectl apply -f deploy/application/service.yaml
```

### Database Migration
TODO: make this a k8s job to remove this manual step
ssh on to one of the application containers and run:
```
python manage.py migrate auth
python manage.py makemigrations
python manage.py migrate
```

### Port Forward
Enable a port forward from 3000 => 80
```
kubectl port-forward service/uur-service 3000:80
```

### Test
You should now have the application up an running. To test you can run.
```
curl 127.0.0.1:3000/quotes
```
This should return a json object imbued with the wisdom of Dr Ricken Lazlo Hale, PhD.