from helium_client import Helium

helium = Helium("/dev/serial0")
helium.connect()

channel = helium.create_channel("Helium MQTT")
channel.send("hello from Python")
