# Requirements

- connect to `observation.genkey.com:4317` and `observation.genkey.com:4318`  
  the observation.genkey.com IP is 172.16.218.143 or 81.246.108.155
- dns resolve for observation.genkey.com
- installed cert authorities, **the site does not force to install self sign cert for security reason**  
  Access to https://observation.genkey.com/ do require tls.
- ENV: all site should identify itself with at least `deployment.environment.name`
- TOKEN: to use https://observation.genkey.com:4317 and 4318 require a token

# run from github

```shell
curl -sfL https://raw.githubusercontent.com/genkeydev/goodies/refs/heads/main/otel/genkey_otel_init.sh -o - | tee /tmp/genkey_otel_init.sh
sudo bash /tmp/genkey_otel_init.sh <ENV> <TOKEN>
# or to use different config
sudo env GENKEY_OTEL_CONFIG_NAME=linux-native-metric.yaml bash -x /tmp/genkey_otel_init.sh <ENV> <TOKEN>

# verify the setup
journalctl -u otelcol-contrib.service -f
 ```

# on https://observation.genkey.com/

Remove the otel receiver, there is one in the compose file.
