import time
import gpiod

CHIP_PATH = "/dev/gpiochip0"
LINE_OFFSET = 18

chip = gpiod.Chip(CHIP_PATH)

line_settings = gpiod.LineSettings()
line_settings.direction = gpiod.line.Direction.OUTPUT

request = chip.request_lines(
    consumer="test-buzzer",
    config={LINE_OFFSET: line_settings},
)

print("Start test")

try:
    while True:
        request.set_value(LINE_OFFSET, gpiod.line.Value.ACTIVE)
        print("ON")
        time.sleep(0.3)

        request.set_value(LINE_OFFSET, gpiod.line.Value.INACTIVE)
        print("OFF")
        time.sleep(2.0)

finally:
    request.set_value(LINE_OFFSET, gpiod.line.Value.INACTIVE)
    request.release()
    chip.close()