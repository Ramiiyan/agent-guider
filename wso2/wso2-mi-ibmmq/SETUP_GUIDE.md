# WSO2 MI 4.x + IBM MQ — Claude Code Setup Guide

> **For Claude Code:** This file is an agentic setup guide. Read it fully before doing anything. Then follow the instructions below — ask the user for information before running any command or making any file change. Never skip a confirmation step.

---

## What This Guide Does

This guide automates the full setup of WSO2 Micro Integrator 4.x connected to IBM MQ via a JMS Inbound Endpoint. It covers:

- Starting IBM MQ in Docker
- Copying and wrapping IBM MQ client JARs into an OSGi bundle
- Generating the JNDI `.bindings` file
- Configuring WSO2 MI (`deployment.toml`, inbound endpoint, sequence)
- Verifying the connection end-to-end

---

## Step 0 — Gather Information Before Starting

**Claude Code: Before running any command or editing any file, ask the user for the following. Present all questions together in one message and wait for their answers.**

Ask the user:

1. **WSO2 MI home path** — the root directory of their extracted WSO2 MI 4.x pack.
   Example: `/opt/wso2mi-4.2.0` or `~/tools/wso2mi-4.2.0`

2. **Java home path** — must be JDK 11, 17 (not 21+). MI 4.2.0 does not support JDK 21+.
   Example: `~/.sdkman/candidates/java/17.0.17-tem` or `/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home`

3. **Working directory** — where to create the `wmq-client/` Maven project for the OSGi bundle build.
   Example: `~/workspace` or `/tmp`

4. **IBM MQ queue name** — the queue MI should listen on. Default: `DEV.QUEUE.1`

5. **Are you on Apple Silicon (M1/M2/M3 Mac)?** — yes or no. This affects the Docker run command.

Store these as variables and use them throughout. Refer to them as:
- `$MI_HOME` — the WSO2 MI home path
- `$JAVA_HOME` — the Java home path
- `$WORK_DIR` — the working directory
- `$MQ_QUEUE` — the queue name
- `$APPLE_SILICON` — true or false

---

## Step 1 — Check Prerequisites

**Claude Code: Run these checks and report the results to the user. If any check fails, tell the user what's needed and ask whether to continue.**

Ask the user for confirmation before running: *"I'll now check that Docker, Java, and Maven are available. OK to proceed?"*

### 1a. Check Docker

```bash
docker info --format '{{.ServerVersion}}'
```

Expected: a version string. If Docker is not running, tell the user to start it and retry.

### 1b. Check Java version

```bash
"$JAVA_HOME/bin/java" -version 2>&1
```

Expected: output containing `17`, `11`, or `16`. If it shows `21` or higher, warn the user — MI 4.2.0 will fail to start. Ask them to provide a valid `$JAVA_HOME` before continuing.

### 1c. Check Maven

```bash
mvn -version
```

Expected: Apache Maven 3.x. If not found, tell the user to install Maven before continuing.

### 1d. Check Docker can pull the IBM MQ image

```bash
docker images icr.io/ibm-messaging/mq --format "{{.Repository}}:{{.Tag}}"
```

If the image is not already pulled, let the user know it will be pulled in Step 2 (it's ~1 GB).

---

## Step 2 — Start IBM MQ in Docker

**Claude Code: Before running, confirm with the user:**
*"I'll start an IBM MQ container named `ibmmq` on ports 1414 and 9443. This will pull the image if not already present (~1 GB). OK to proceed?"*

If `$APPLE_SILICON` is true, include `--platform linux/amd64`. If false, omit it.

**For Apple Silicon:**

```bash
docker run -d \
  --name ibmmq \
  --platform linux/amd64 \
  --env LICENSE=accept \
  --env MQ_QMGR_NAME=QM1 \
  --env MQ_APP_PASSWORD=passw0rd \
  --env MQ_ADMIN_PASSWORD=passw0rd \
  -p 1414:1414 \
  -p 9443:9443 \
  icr.io/ibm-messaging/mq:latest
```

**For Intel/Linux:**

```bash
docker run -d \
  --name ibmmq \
  --env LICENSE=accept \
  --env MQ_QMGR_NAME=QM1 \
  --env MQ_APP_PASSWORD=passw0rd \
  --env MQ_ADMIN_PASSWORD=passw0rd \
  -p 1414:1414 \
  -p 9443:9443 \
  icr.io/ibm-messaging/mq:latest
```

After running, wait 30 seconds then verify:

```bash
docker logs ibmmq 2>&1 | grep "Started queue manager"
```

If the grep returns nothing, wait another 15 seconds and retry once. If it still fails, show the last 20 lines of logs to the user and ask how to proceed.

---

## Step 3 — Copy IBM MQ Client JARs

**Claude Code: Before running, confirm:**
*"I'll copy the IBM MQ client JARs from the container into `$WORK_DIR/wmq-client/lib/`. OK?"*

```bash
mkdir -p "$WORK_DIR/wmq-client/lib"

for jar in com.ibm.mq.allclient.jar jms.jar fscontext.jar providerutil.jar; do
  docker cp "ibmmq:/opt/mqm/java/lib/$jar" "$WORK_DIR/wmq-client/lib/$jar"
done
```

Verify all four JARs were copied:

```bash
ls "$WORK_DIR/wmq-client/lib/"
```

Expected output: the four JAR files. If any are missing, report which ones and stop.

---

## Step 4 — Build the OSGi Bundle

**Why:** WSO2 MI runs on an OSGi runtime (Eclipse Equinox) with its own embedded `javax.jms`. Placing raw IBM MQ JARs in `lib/` causes a classloader conflict and a `ClassCastException`. Wrapping them into an OSGi bundle and placing it in `dropins/` solves this cleanly.

**Claude Code: Before writing any file, confirm:**
*"I'll create `$WORK_DIR/wmq-client/pom.xml` and build the OSGi bundle with Maven. This will take a minute. OK to proceed?"*

Write the following to `$WORK_DIR/wmq-client/pom.xml`:

```xml
<?xml version="1.0"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>wmq-client</groupId>
    <artifactId>wmq-client</artifactId>
    <version>9.4.5.0</version>
    <packaging>bundle</packaging>
    <dependencies>
        <dependency>
            <groupId>com.ibm</groupId>
            <artifactId>fscontext</artifactId>
            <version>9.4.5.0</version>
            <scope>system</scope>
            <systemPath>${basedir}/lib/fscontext.jar</systemPath>
        </dependency>
        <dependency>
            <groupId>com.ibm</groupId>
            <artifactId>providerutil</artifactId>
            <version>9.4.5.0</version>
            <scope>system</scope>
            <systemPath>${basedir}/lib/providerutil.jar</systemPath>
        </dependency>
        <dependency>
            <groupId>com.ibm</groupId>
            <artifactId>allclient</artifactId>
            <version>9.4.5.0</version>
            <scope>system</scope>
            <systemPath>${basedir}/lib/com.ibm.mq.allclient.jar</systemPath>
        </dependency>
        <dependency>
            <groupId>javax.jms</groupId>
            <artifactId>jms</artifactId>
            <version>2.0</version>
            <scope>system</scope>
            <systemPath>${basedir}/lib/jms.jar</systemPath>
        </dependency>
    </dependencies>
    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.felix</groupId>
                <artifactId>maven-bundle-plugin</artifactId>
                <version>5.1.9</version>
                <extensions>true</extensions>
                <configuration>
                    <instructions>
                        <Bundle-SymbolicName>${project.artifactId}</Bundle-SymbolicName>
                        <Bundle-Name>${project.artifactId}</Bundle-Name>
                        <Export-Package>*;-split-package:=merge-first</Export-Package>
                        <Private-Package/>
                        <Import-Package/>
                        <Embed-Dependency>*;scope=system;inline=true</Embed-Dependency>
                        <DynamicImport-Package>*</DynamicImport-Package>
                    </instructions>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
```

Then build:

```bash
cd "$WORK_DIR/wmq-client" && mvn clean install
```

Verify the bundle was produced:

```bash
ls "$WORK_DIR/wmq-client/target/wmq-client-9.4.5.0.jar"
```

If the file is missing, show the Maven output to the user and stop.

---

## Step 5 — Install JARs Into MI

**Claude Code: Before running, confirm:**
*"I'll copy the OSGi bundle into `$MI_HOME/dropins/` and download `jta.jar` into `$MI_HOME/lib/`. OK?"*

```bash
cp "$WORK_DIR/wmq-client/target/wmq-client-9.4.5.0.jar" "$MI_HOME/dropins/"

curl -o "$MI_HOME/lib/jta.jar" \
  https://repo1.maven.org/maven2/javax/transaction/jta/1.1/jta-1.1.jar
```

Verify:

```bash
ls "$MI_HOME/dropins/wmq-client-9.4.5.0.jar"
ls "$MI_HOME/lib/jta.jar"
```

---

## Step 6 — Generate the JNDI `.bindings` File

**Important:** Use `DEFINE QCF(...)` — not `DEFINE CF(...)`. WSO2 MI's JMS transport casts the looked-up factory to `javax.jms.QueueConnectionFactory`. Using the generic `CF` type causes a `ClassCastException` at startup.

**Claude Code: Before running, confirm:**
*"I'll run IBM MQ's JMSAdmin tool inside the container to generate a JNDI `.bindings` file, then copy it to `$MI_HOME/repository/conf/jndi/`. OK?"*

```bash
docker exec ibmmq bash -c "mkdir -p /tmp/jndi"

docker exec ibmmq bash -c "cat > /tmp/JMSAdmin.config << 'EOF'
INITIAL_CONTEXT_FACTORY=com.sun.jndi.fscontext.RefFSContextFactory
PROVIDER_URL=file:///tmp/jndi
EOF"

docker exec ibmmq bash -c "cat > /tmp/jmsadmin_cmds.txt << 'EOF'
DEFINE QCF(ConnectionFactory) QMGR(QM1) CHANNEL(DEV.APP.SVRCONN) HOSTNAME(localhost) PORT(1414) TRANSPORT(CLIENT)
DEFINE Q(DEV.QUEUE.1) QUEUE(DEV.QUEUE.1) QMGR(QM1)
END
EOF"

docker exec ibmmq bash -c \
  "cd /tmp && /opt/mqm/java/bin/JMSAdmin -cfg /tmp/JMSAdmin.config < /tmp/jmsadmin_cmds.txt"
```

Copy the `.bindings` file to MI:

```bash
mkdir -p "$MI_HOME/repository/conf/jndi"
docker cp ibmmq:/tmp/jndi/.bindings "$MI_HOME/repository/conf/jndi/.bindings"
```

Verify:

```bash
ls "$MI_HOME/repository/conf/jndi/.bindings"
```

---

## Step 7 — Configure `deployment.toml`

**Claude Code: Before editing, confirm:**
*"I'll append the JMS transport listener config to `$MI_HOME/conf/deployment.toml`. I'll check first whether a `[[transport.jms.listener]]` block already exists and will not duplicate it. OK?"*

Check if JMS listener config already exists:

```bash
grep -c "transport.jms.listener" "$MI_HOME/conf/deployment.toml" || echo "0"
```

If the count is 0, append the following. If it's already present, tell the user and skip this step.

```toml
[[transport.jms.listener]]
name = "MyQueueConnectionFactory"
parameter.initial_naming_factory = "com.sun.jndi.fscontext.RefFSContextFactory"
parameter.provider_url = "file://$MI_HOME/repository/conf/jndi"
parameter.connection_factory_name = "ConnectionFactory"
parameter.connection_factory_type = "queue"
parameter.username = "app"
parameter.password = "passw0rd"

[[transport.jms.listener]]
name = "default"
parameter.initial_naming_factory = "com.sun.jndi.fscontext.RefFSContextFactory"
parameter.provider_url = "file://$MI_HOME/repository/conf/jndi"
parameter.connection_factory_name = "ConnectionFactory"
parameter.connection_factory_type = "queue"
parameter.username = "app"
parameter.password = "passw0rd"
```

> **Note:** Substitute the literal value of `$MI_HOME` into `parameter.provider_url` — this is a file path string, not a shell variable that MI will expand at runtime.

---

## Step 8 — Create the JMS Inbound Endpoint

**Claude Code: Before writing, confirm:**
*"I'll create the inbound endpoint XML at `$MI_HOME/repository/deployment/server/synapse-configs/default/inbound-endpoints/IBMMQ_Inbound.xml`. OK?"*

```bash
mkdir -p "$MI_HOME/repository/deployment/server/synapse-configs/default/inbound-endpoints"
```

Write the following to `$MI_HOME/repository/deployment/server/synapse-configs/default/inbound-endpoints/IBMMQ_Inbound.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<inboundEndpoint name="IBMMQ_Inbound" sequence="IBMMQ_Log_Seq" onError="fault"
                 protocol="jms" suspend="false"
                 xmlns="http://ws.apache.org/ns/synapse">
    <parameters>
        <parameter name="interval">5000</parameter>
        <parameter name="sequential">true</parameter>
        <parameter name="coordination">true</parameter>
        <parameter name="java.naming.factory.initial">com.sun.jndi.fscontext.RefFSContextFactory</parameter>
        <parameter name="java.naming.provider.url">file://$MI_HOME/repository/conf/jndi</parameter>
        <parameter name="transport.jms.ConnectionFactoryJNDIName">ConnectionFactory</parameter>
        <parameter name="transport.jms.ConnectionFactoryType">queue</parameter>
        <parameter name="transport.jms.Destination">$MQ_QUEUE</parameter>
        <parameter name="transport.jms.DestinationType">queue</parameter>
        <parameter name="transport.jms.UserName">app</parameter>
        <parameter name="transport.jms.Password">passw0rd</parameter>
        <parameter name="transport.jms.SessionAcknowledgement">CLIENT_ACKNOWLEDGE</parameter>
        <parameter name="transport.jms.CacheLevel">3</parameter>
        <parameter name="transport.jms.SessionTransacted">false</parameter>
        <parameter name="transport.jms.ResetConnectionOnFailure">true</parameter>
        <parameter name="transport.jms.RetriesBeforeSuspension">5</parameter>
        <parameter name="transport.jms.PollingSuspensionPeriod">3000</parameter>
        <parameter name="redeliveryPolicy.maximumRedeliveries">5</parameter>
        <parameter name="redeliveryPolicy.initialRedeliveryDelay">2000</parameter>
    </parameters>
</inboundEndpoint>
```

> **Note:** Substitute the literal values of `$MI_HOME` and `$MQ_QUEUE` into the XML — these are not runtime variables.

---

## Step 9 — Create the Processing Sequence

**Claude Code: Before writing, confirm:**
*"I'll create a simple logging sequence at `$MI_HOME/repository/deployment/server/synapse-configs/default/sequences/IBMMQ_Log_Seq.xml`. This just logs every received message. OK?"*

```bash
mkdir -p "$MI_HOME/repository/deployment/server/synapse-configs/default/sequences"
```

Write the following to `$MI_HOME/repository/deployment/server/synapse-configs/default/sequences/IBMMQ_Log_Seq.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<sequence xmlns="http://ws.apache.org/ns/synapse" name="IBMMQ_Log_Seq">
    <log level="full">
        <property name="STATUS" value="MESSAGE RECEIVED FROM IBM MQ"/>
    </log>
    <drop/>
</sequence>
```

---

## Step 10 — Start WSO2 MI

**Claude Code: Before running, confirm:**
*"I'll start WSO2 MI using `$JAVA_HOME`. MI will run in the foreground and output logs to the terminal. OK to start?"*

```bash
export JAVA_HOME="$JAVA_HOME"
export PATH="$JAVA_HOME/bin:$PATH"
"$MI_HOME/bin/micro-integrator.sh"
```

Watch for these lines in the output confirming successful setup:

```
INFO {InboundEndpoint} - Initializing Inbound Endpoint: IBMMQ_Inbound
INFO {JMSProcessor} - Initializing inbound JMS listener for inbound endpoint IBMMQ_Inbound
INFO {AbstractQuartzTaskManager} - Task scheduled: [ESB_TASK][IBMMQ_Inbound-JMS--SYNAPSE_INBOUND_ENDPOINT0]
```

If these lines appear, tell the user the setup is complete. If MI fails to start, show the last 30 lines of log output and ask how to proceed.

---

## Step 11 — Test the Connection

**Claude Code: Before running, confirm:**
*"I'll put a test SOAP message on `$MQ_QUEUE` using the IBM MQ sample utility inside the container. Check the MI logs for the message after this. OK?"*

```bash
docker exec ibmmq bash -c "printf '<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\">
  <soapenv:Body><test>Hello from IBM MQ!</test></soapenv:Body>
</soapenv:Envelope>' | /opt/mqm/samp/bin/amqsput $MQ_QUEUE QM1"
```

Tell the user to look for this in the MI logs:

```
INFO {LogMediator} - {inboundendpoint:IBMMQ_Inbound} STATUS = MESSAGE RECEIVED FROM IBM MQ
```

If seen, the full setup is working. Congratulate the user and summarise what was set up.

---

## Reference — Configuration Values Used

| Parameter | Value |
|---|---|
| Queue Manager | `QM1` |
| Channel | `DEV.APP.SVRCONN` |
| Queue | `$MQ_QUEUE` (user-provided) |
| MQ Port | `1414` |
| MQ Web Console | `https://localhost:9443/ibmmq/console` |
| App username | `app` |
| App password | `passw0rd` |
| Admin password | `passw0rd` |

---

## Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `ClassCastException: MQConnectionFactory cannot be cast to QueueConnectionFactory` | Raw IBM MQ JARs in `lib/` | Ensure only the OSGi bundle is in `dropins/` |
| Same `ClassCastException` even with bundle | `.bindings` used `CF` not `QCF` | Regenerate with `DEFINE QCF(...)` (Step 6) |
| `NoInitialContextException` | Wrong JNDI factory class | Use `com.sun.jndi.fscontext.RefFSContextFactory` |
| `no matching manifest for linux/arm64` | IBM MQ image is `amd64` only | Add `--platform linux/amd64` to `docker run` |
| MI won't start — `JDK not supported` | JDK 21+ detected | Set `JAVA_HOME` to JDK 11–17 |
