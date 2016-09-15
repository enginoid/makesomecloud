apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: helloworld
spec:
  strategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        name: helloworld
        version: {{ GITHASH }}
        track: production
    spec:
      containers:
      - name: helloworld
        image: {{ DOCKER_REGISTRY }}/helloworld:{{ GITHASH }}
        ports:
        - containerPort: 8080
          name: http
---
apiVersion: v1
kind: Service
metadata:
  name: helloworld
spec:
  ports:
  - port: 80
    targetPort: 8080
    name: http
  selector:
    name: helloworld
  type: LoadBalancer
