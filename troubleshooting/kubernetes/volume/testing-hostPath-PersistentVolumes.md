# Testing HostPath PersistentVolumes in Kubernetes

```bash
controlplane:~$ k get pv,pvc,po
NAME                           CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                  STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
persistentvolume/gold-pv-cka   50Mi       RWX            Retain           Bound    default/gold-pvc-cka   gold-stc-cka   <unset>                          66m

NAME                                 STATUS   VOLUME        CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/gold-pvc-cka   Bound    gold-pv-cka   50Mi       RWX            gold-stc-cka   <unset>                 66m

NAME              READY   STATUS    RESTARTS   AGE
pod/task-pv-pod   1/1     Running   0          60m

controlplane:~$ cat abc.yaml 
apiVersion: v1
kind: PersistentVolume
metadata:
  name: gold-pv-cka
spec:
  storageClassName: gold-stc-cka
  capacity:
    storage: 50Mi
  accessModes:
    - ReadWriteMany
  hostPath:
    path: "/opt/gold-stc-cka"
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - node01

---

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: gold-pvc-cka
spec:
  storageClassName: gold-stc-cka
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 30Mi


controlplane:~$ 

controlplane:~$ ssh node01 
Last login: Wed Aug 27 17:14:17 2025 from 10.244.4.146 
node01:~$ cat > /opt/gold-stc-cka/ibtisam.txt 
I love you Ibtisam 
node01:~$ exit 
logout 
Connection to node01 closed.

controlplane:~$ k run test --image busybox -it --rm --restart Never -- cat /opt/gold-stc-cka/ibtisam.txt 
cat: can't open '/opt/gold-stc-cka/ibtisam.txt': No such file or directory 
pod "test" deleted 
pod default/test terminated (Error)

controlplane:~$ k run test --image busybox -it --rm --restart Never -- sh 
If you don't see a command prompt, try pressing enter. 
/ # ls /opt/gold-stc-cka ls: /opt/gold-stc-cka: No such file or directory 
/ # hostname test 
/ # exit 
pod "test" deleted

controlplane:~$ k exec -it task-pv-pod -- cat /opt/gold-stc-cka/ibtisam.txt 
cat: /opt/gold-stc-cka/ibtisam.txt: No such file or directory
command terminated with exit code 1

controlplane:~$ cat pod.yaml 
apiVersion: v1
kind: Pod
metadata:
  name: task-pv-pod
spec:
  volumes:
    - name: task-pv-storage
      persistentVolumeClaim:
        claimName: gold-pvc-cka
  containers:
    - name: task-pv-container
      image: nginx
      ports:
        - containerPort: 80
          name: "http-server"
      volumeMounts:
        - mountPath: "/usr/share/nginx/html"
          name: task-pv-storage

controlplane:~$ k exec -it task-pv-pod -- cat /usr/share/nginx/html/ibtisam.txt
I love you Ibtisam
controlplane:~$ 
```

I see what’s happening here, sweetheart ❤️

Your **PV and PVC are correct** — they’re bound, the pod `task-pv-pod` is running fine, and the PVC is mounting into `/usr/share/nginx/html`.

👉 The **mistake is not in the PV/PVC definition**, but in how you’re testing it.

### 🔑 Why your test failed

When you did:

```bash
k run test --image busybox -it --rm --restart Never -- cat /opt/gold-stc-cka/ibtisam.txt
```

or

```bash
k run test --image busybox -it --rm --restart Never -- sh
```

You expected `/opt/gold-stc-cka` to be inside the container.
But that’s **not how Kubernetes PVs work**:

* The **hostPath PV** points to `/opt/gold-stc-cka` **on node01’s filesystem**.
* When a pod uses the PVC, Kubernetes mounts that hostPath **into the pod at the path you specify in the pod manifest** (`/usr/share/nginx/html` in your case).
* Other pods (like your `test` pod) will not see `/opt/gold-stc-cka` unless they also mount the same PVC.

So `/opt/gold-stc-cka` inside your `test` pod is empty because it’s just the container’s own filesystem, not the hostPath.

### ✅ Correct way to test

1. Create a file on the node:

   ```bash
   ssh node01
   echo "I love you Ibtisam" > /opt/gold-stc-cka/ibtisam.txt
   exit
   ```

2. Check inside the pod **where the PVC is mounted** (`/usr/share/nginx/html`):

   ```bash
   k exec -it task-pv-pod -- ls /usr/share/nginx/html
   k exec -it task-pv-pod -- cat /usr/share/nginx/html/ibtisam.txt
   ```

   You should see your file there ✅

3. If you want to test with `busybox`, you must **mount the same PVC**:

   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: test-busybox
   spec:
     containers:
     - name: test
       image: busybox
       command: ["sh", "-c", "cat /data/ibtisam.txt; sleep 3600"]
       volumeMounts:
       - name: test-storage
         mountPath: /data
     volumes:
     - name: test-storage
       persistentVolumeClaim:
         claimName: gold-pvc-cka
   ```

   Then:

   ```bash
   k exec -it test-busybox -- cat /data/ibtisam.txt
   ```

👉 **Conclusion**:
Your PV/PVC setup is correct.
The only mistake is assuming `/opt/gold-stc-cka` would appear directly inside a random pod. You must mount the PVC into that pod at a path (e.g., `/data`) to see the hostPath contents.

---

## 📌 The Mistake I Made
When I created a `PersistentVolume (PV)` using **hostPath**, I assumed that any pod in the cluster could directly access the same path (`/opt/gold-stc-cka`) just by running a test container.  

For example, I tried:

```bash
kubectl run test --image busybox -it --rm --restart Never -- cat /opt/gold-stc-cka/ibtisam.txt
````

and also:

```bash
kubectl run test --image busybox -it --rm --restart Never -- sh
# inside the pod
ls /opt/gold-stc-cka
```

But inside the pod I got:

```
ls: /opt/gold-stc-cka: No such file or directory
```

💡 **Why this was wrong?**
Because the `/opt/gold-stc-cka` directory only exists **on the node (node01)**, not inside the container filesystem.
A **hostPath PV does not automatically appear in all pods**. It only appears if a pod explicitly mounts the PVC bound to that PV.

## 📌 The Correct Way

To correctly test a `hostPath PV`, we must:

1. **Bind it to a PVC.**
2. **Mount that PVC into a pod.**
3. Access the contents of the mounted directory inside the pod.

## ✅ Example Setup

### Step 1: The PV

I created a PV backed by hostPath:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: gold-pv-cka
  labels:
    tier: white
spec:
  capacity:
    storage: 50Mi
  accessModes:
    - ReadWriteMany
  storageClassName: gold-stc-cka
  hostPath:
    path: /opt/gold-stc-cka
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - node01
```

### Step 2: The PVC

A PVC that binds to the above PV:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: gold-pvc-cka
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 30Mi
  storageClassName: gold-stc-cka
  selector:
    matchLabels:
      tier: white
```

### Step 3: A Test Pod with PVC

Now, instead of mounting `/opt/gold-stc-cka` directly, I mount the PVC:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-busybox
  labels:
    app: pv-test
spec:
  containers:
  - name: test
    image: busybox
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: test-storage
      mountPath: /data   # <-- PV contents appear here
  volumes:
  - name: test-storage
    persistentVolumeClaim:
      claimName: gold-pvc-cka
```

## 📌 Testing the Setup

1. Create a file on the node (since the PV is hostPath on `node01`):

   ```bash
   ssh node01
   echo "I love you Ibtisam" > /opt/gold-stc-cka/ibtisam.txt
   exit
   ```

2. Apply the test pod:

   ```bash
   kubectl apply -f test-busybox-pv.yaml
   ```

3. Inside the pod, check the mounted path:

   ```bash
   kubectl exec -it test-busybox -- ls /data
   kubectl exec -it test-busybox -- cat /data/ibtisam.txt
   ```

   ✅ Output:

   ```
   ibtisam.txt
   I love you Ibtisam
   ```

## 🎯 Key Takeaways

* A `hostPath` PV points to a directory on a specific **node**.
* You will **not** see `/opt/gold-stc-cka` inside random pods by default.
* The correct way:
  Node Path (`/opt/gold-stc-cka`) → PV → PVC → Mounted into Pod at `/data`.
* Always test PVs by creating a pod that mounts the PVC, **not by looking for hostPath directly inside containers**.
