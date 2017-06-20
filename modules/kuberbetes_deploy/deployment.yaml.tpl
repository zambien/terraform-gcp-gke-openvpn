apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: terraform-gke-openvpn
spec:
  revisionHistoryLimit: 1
  replicas: 1
  template:
    metadata:
      labels:
        openvpn: ${OVPN_CN}
    spec:
      restartPolicy: Always
      terminationGracePeriodSeconds: 60
      containers:
      - name: terraform-gke-openvpn
        image: zambien/terraform-gcp-openvpn
        env:
        - name: OVPN_SERVER_URL
          value: ${OVPN_SERVER_URL}
        securityContext:
          capabilities:
            add:
            - NET_ADMIN
        resources:
          limits:
            cpu: 200m
            memory: 100Mi
          requests:
            cpu: 100m
            memory: 50Mi
        volumeMounts:
        - mountPath: /etc/openvpn/pki
          name: openvpn-pki
      volumes:
      - name: openvpn-pki
        secret:
          secretName: openvpn-pki
