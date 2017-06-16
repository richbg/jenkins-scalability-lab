# Start git server  https://github.com/jkarlosb/git-server-docker
# Hacks due to limitations on use of compose with docker IO resource limits, boo
LOCAL_DIR="$(pwd)"
docker run --rm -d -p 2222:22 \
   -h gitserver \
   --name gitserver \
   -v "$LOCAL_DIR/gitserver/keys:/git-server/keys" \
   -v "$LOCAL_DIR/gitserver/repos:/git-server/repos" \
   jkarlos/git-server-docker

# TODO generate pubkey with ssh-keygen -t rsa and copy to gitserver and jenkins?
mkdir -p gitserver/keys || true
ssh-keygen -t rsa -n "" -P "" -f id_rsa \
    && cp id_rsa.pub gitserver/keys \
    && cp id_rsa* jenkins
JENKINS_PUB_KEY=$(cat gitserver/keys/id_rsa.pub)

# Start slave agent executors, names "agent-1, agent-2, etc"
AGENT_LIST=""
AGENT_LINKS=""
for (( c=1; c<=4; c++ )); do
    AGENT_NAME="agent-${c}"
    docker run -d --rm \
      -h "$AGENT_NAME" --name "$AGENT_NAME" --link gitserver \
      jenkinsci/ssh-slave "$JENKINS_PUB_KEY"
    AGENT_LIST="$AGENT_LIST $AGENT_NAME"
    AGENT_LINKS="$AGENT_LINKS --link $AGENT_NAME"
    # TODO create a string of all agent names
done

# Build jenkins
docker build -t jenkins-scalability-master:1.0 ./jenkins

# Graphite server
docker run -d \
  -h graphite --name graphite \
  -p 81:80 \
  -p 2003:2003 \
  -p 8125:8125/udp \
  hopsoft/graphite-statsd


# Run jenkins
docker run -it --rm  -h jenkins --name jenkins \
  --device-write-iops /dev/vda:200 --device-write-bps /dev/vda:100mb --device-read-iops /dev/vda:200 --device-read-bps /dev/vda:100mb \
  -p 8080:8080 \
  --link graphite
  --link gitserver $AGENT_LINKS\
  -v /Users/svanoort/Documents/jenkins-scalability-lab/jenkins/jenkins_home:/var/jenkins_home \
  jenkins-scalability-master:1.0