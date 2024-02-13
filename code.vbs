esphome:
  name: werkbank
  platform: ESP32
  board: esp32doit-devkit-v1
  on_boot:
    priority: -100 #lowest priority so start last
    then:
       - lambda: id(pwm_output_fan).turn_off(); #turn off the fan at boot time

# Enable logging
logger:

# Enable Home Assistant API
api:

ota:
  password: "bc2621ee78b56c1ca88cdad4d16be25e"

wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password

  # Enable fallback hotspot (captive portal) in case wifi connection fails
  ap:
    ssid: "Werkbank Fallback Hotspot"
    password: "GI2Rns4RjEYY"

captive_portal:

#https://esphome.io/guides/automations.html?highlight=helper
#Global variable which can be used over multiple lambda's
#Start the fan at an initial value
globals:
   - id: num_Fan_Set_Speed
     type: double
     restore_value: no
     initial_value: '0'

# Add virtual switch to remotely restart the ESP via HA
# https://esphome.io/components/switch/restart
button:
  - platform: restart
    name: "ESP_Werkbank restart"


#control the PWM fan
#https://esphome.io/components/fan/speed.html
output:
  - platform: ledc
    pin: GPIO25
    frequency: 1000 Hz
    id: pwm_output_fan

fan:
  - platform: speed
    output: pwm_output_fan
    name: "Werkbank-Ventilator"


#https://esphome.io/components/sensor/pulse_counter.html
#Get the RPM of one fan
sensor:
  - platform: pulse_counter
    pin: GPIO26
    name: "Werkbank-Ventilator-RPM"
    update_interval: 30s
    unit_of_measurement: 'RPM'
    filters:
      - multiply: 0.5 #fan runs according to specs 3500rpm, so need to convert the received pulses as that was max 8000

  - platform: dht
    pin: GPIO27
    model: DHT11
    temperature:
      name: "Werkbank-Temperature"
      id: th14_temp
    humidity:
      name: "Werkbank-Humidity"
      id: th14_humidity
    update_interval: 10s

#https://esphome.io/components/sensor/rotary_encoder.html
  - platform: rotary_encoder
    name: "Rotary Encoder"
    pin_a: 
      number: GPIO18
      inverted: true
      mode:
        input: true
        pullup: true
    pin_b: 
      number: GPIO19
      inverted: true
      mode:
        input: true
        pullup: true
    on_clockwise:
      then:
        - logger.log: "Turned Clockwise"
        - lambda: |-
              // global value will be increased by 10
              if (id(num_Fan_Set_Speed) < 100) {
              id(num_Fan_Set_Speed) += 10;
              id(pwm_output_fan).set_level(id(num_Fan_Set_Speed)/100); //set the speed level between 0 and 1 https://esphome.io/components/output/index.html
              }

    on_anticlockwise:
      - logger.log: "Turned Anticlockwise"
      - lambda: |-
              if (id(num_Fan_Set_Speed) > 10) {  //Below 10 the fan stops spinning due to the electrical characteristics of the fan
              // global value will be decreased by 10
              id(num_Fan_Set_Speed) -= 10;
              id(pwm_output_fan).set_level(id(num_Fan_Set_Speed)/100);
              }
              else {
                id(num_Fan_Set_Speed) = 0;
                id(pwm_output_fan).turn_off();
              }
  
#https://esphome.io/components/binary_sensor/gpio
binary_sensor:
  - platform: gpio
    pin:
      number: GPIO17
      mode:
        input: true
        pullup: true
    name: "Rotary_Push_Sensor"
    filters:
      - delayed_on: 10ms #against debouncing
      - delayed_off: 10ms
    on_release:
      - lambda: |-
            id(num_Fan_Set_Speed) = 0;
            id(pwm_output_fan).turn_off();      

#Get value from Helper in Home Assistant
#https://esphome.io/components/binary_sensor/homeassistant.html
  - platform: homeassistant
    id: override_from_home_assistant_helper
    entity_id: input_boolean.werkbank_ventilator_override


#display: TM1637
#https://esphome.io/components/display/tm1637.html?highlight=tm1637
display:
    platform: tm1637
    id: tm1637_display
    clk_pin: GPIO22
    dio_pin: GPIO21
    intensity: 0 # Ranging from 0 - 7 where 7 is the brightest
    #Make sure that any comment in the lambda code block is started with // as all
    #  code in the block is C++.
    lambda: |-
        // Print 0 at position 0 (left)
        it.printf(0, "%.0f", id(num_Fan_Set_Speed));
    #end code

time:
  - platform: homeassistant
    id: homeassistant_time

    on_time:
      - seconds: /10  # needs to be set, otherwise every second this is triggered!
        minutes: '*'  # Trigger every 2 minutes
        then:
          lambda: !lambda |-
            auto time = id(homeassistant_time).now();
            int t_now = parse_number<int>(id(homeassistant_time).now().strftime("%H%M")).value();
            
    #end code