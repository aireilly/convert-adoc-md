# Test Callouts

Learn about NUMA-aware scheduling and how you can use it to deploy high performance workloads in a cluster.

> [!NOTE]
> This is tricky!

``` yaml
some
  # crai
  yaml
    here: be
```

Yes.

Ok, now what about in an ol?

1.  Do this:

    ``` yaml
    apiVersion: machineconfiguration.openshift.io/v1
    # crai23
    kind: KubeletConfig
    metadata:
      name: worker-tuning
    # crai34 hi
    spec:
      machineConfigPoolSelector:
        matchLabels:
          pools.operator.machineconfiguration.openshift.io/worker: ""
      kubeletConfig:
        cpuManagerPolicy: "static"
        # geeep
        cpuManagerReconcilePeriod: "5s"
        reservedSystemCPUs: "0,1"
        memoryManagerPolicy: "Static"
        evictionHard:
          # deeep
          memory.available: "100Mi"
        kubeReserved:
          memory: "512Mi"
        reservedMemory:
          - numaNode: 0
            limits:
              # poop
              memory: "1124Mi"
        systemReserved:
          memory: "512Mi"
        topologyManagerPolicy: "single-numa-node"
    ```

2.  Stuff. yes lots of stuff!

    1.  And then do this:

        1.  Go deep.

        2.  And deeper again:

            ``` yaml
            more
              # foo foo foo
              yaml
                # boop
                more: yaml
            ```

> [!NOTE]
> This is a WIP project playing with moving adoc to md.

``` yaml
apiVersion: nodetopology.openshift.io/v1
kind: NUMAResourcesScheduler
metadata:
  # In a disconnected environment, make sure to configure the resolution of this image by either:
  # - Creating an `ImageTagMirrorSet` custom resource (CR).
  # - Setting the URL to the disconnected registry.
  name: numaresourcesscheduler
spec:
  imageSpec: "registry.redhat.io/openshift4/noderesourcetopology-scheduler-rhel9:v2"
```

``` terminal
# pew pew pew
$ here's a codeblock!
```
