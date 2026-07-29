FROM python:3.12 AS builder

RUN apt-get update && \
    apt-get install --yes --no-install-recommends \
      build-essential cmake ninja-build git

WORKDIR /app

COPY pyproject.toml setup.py CMakeLists.txt MANIFEST.in README.md ./
COPY src/piper/ ./src/piper/
COPY script/setup script/dev_build script/package ./script/
RUN script/setup --dev
RUN script/dev_build
RUN script/package

# -----------------------------------------------------------------------------

FROM python:3.12-slim

ENV PIP_BREAK_SYSTEM_PACKAGES=1

WORKDIR /app
COPY --from=builder /app/dist/piper_tts-*linux*.whl ./dist/
RUN pip3 install ./dist/piper_tts-*linux*.whl
RUN pip3 install 'flask>=3,<4'

RUN python3 -m piper.download_voices --data-dir /data \
      en_US-lessac-high en_US-amy-medium en_US-kristin-medium en_US-joe-medium \
      en_GB-alan-medium en_GB-northern_english_male-medium en_GB-alba-medium en_GB-cori-high \
      de_DE-thorsten_emotional-medium

EXPOSE 5000

# No ENTRYPOINT: Railway's container runtime execs CMD directly rather than
# combining it with ENTRYPOINT the way plain Docker does, so entrypoint.sh's
# "server" keyword (a shell-script convenience, not a real binary) isn't
# resolvable there. CMD is the full, standalone server invocation instead.
CMD ["python3", "-m", "piper.http_server", "--host", "0.0.0.0", "--data-dir", "/data", "-m", "en_US-joe-medium"]
