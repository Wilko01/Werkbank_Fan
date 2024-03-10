esphome:
  name: werkbank
  platform: ESP32
  board: esp32doit-devkit-v1
  on_boot:
    priority: -100 #lowest priority so start last
    then:
       #- lambda: id(pwm_output_fan).turn_off(); #turn off the fan at boot time

      - lambda: |-
          id(pwm_output_fan).turn_off(); //turn off the fan at boot time
          if (id(Werkbank_Ventilator_Override).state)
            {
             id(LED_Werkbank_Ventilator_Override).set_level(0.1); //set the level between 0.0 and 1 https://esphome.io/components/output/index.html
            }
            else 
            {
            id(LED_Werkbank_Ventilator_Override).set_level(id(0));
            }
          if (id(werkbank_mode_local).state)
            {
             id(LED_Mode_Local).set_level(0.1); //set the level between 0 and 1 https://esphome.io/components/output/index.html
             id(LED_Mode_Remote).set_level(0);
            }
            else 
            {
            id(LED_Mode_Local).set_level(id(0));
            id(LED_Mode_Remote).set_level(0.1);
            }



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

#switch will be created in Home Assistant and is used to indicate which mode is used. local or remote. Every time the momentary button is pressed the mode changes from state
#https://esphome.io/guides/automations.html?highlight=helpe
#https://esphome.io/components/switch/#switch-on-turn-on-off-trigger
switch:
  - platform: gpio
    pin: GPIO3
    name: "Werkbank_Mode_Local"
    id: werkbank_mode_local
    on_turn_on: 
    - logger.log: "Switch Turned On!"
    #- output.turn_on: LED_Mode_Local
    - output.set_level:
        id: LED_Mode_Local
        level: "8%"   #sets the level of intensity
    - output.turn_off: LED_Mode_Remote
    on_turn_off:
    - logger.log: "Switch Turned Off!"
    - output.turn_off: LED_Mode_Local
    #- output.turn_on: LED_Mode_Remote
    - output.set_level:
        id: LED_Mode_Remote
        level: "8%"


#Create a virtual switch to be automatically created in Home Assistant. This solves the issue to create the helper in Home Assistant while I don't know yet how to get the state
  - platform: gpio
    pin: GPIO23 #Use a not used pin to ensure this virtual switch is not switching anything
    name: "Werkbank_Ventilator_Override"
    id: Werkbank_Ventilator_Override
    on_turn_on: 
    #- output.turn_on: LED_Werkbank_Ventilator_Override
    - output.set_level:
        id: LED_Werkbank_Ventilator_Override
        level: "8%"   #sets the level of intensity
    on_turn_off:
    - output.turn_off: LED_Werkbank_Ventilator_Override


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

#control the Red LED to indicate mode home assistant override
  - platform: ledc
    pin: GPIO13
    frequency: 1000 Hz
    id: LED_Werkbank_Ventilator_Override
    
#control the Blue LED to indicate mode local
  - platform: ledc
    pin: GPIO12
    frequency: 1000 Hz
    id: LED_Mode_Local
    
#control the Green LED to indicate mode remote
  - platform: ledc
    pin: GPIO14
    frequency: 1000 Hz
    id: LED_Mode_Remote

fan:
  - platform: speed
    output: pwm_output_fan
    name: "Werkbank_Ventilator"

#https://esphome.io/components/output/ledc
light:
  - platform: monochromatic
    output: LED_Werkbank_Ventilator_Override
    name: "LED_Werkbank_Ventilator_Override"
    
  - platform: monochromatic
    output: LED_Mode_Local
    name: "LED_Werkbank_Mode_Local"
  
  - platform: monochromatic
    output: LED_Mode_Remote
    name: "LED_Werkbank_Mode_Remote"
    
    
#https://esphome.io/components/sensor/pulse_counter.html
#Get the RPM of one fan
sensor:
  - platform: pulse_counter
    pin: GPIO26
    name: "Werkbank_Ventilator_RPM"
    update_interval: 30s
    unit_of_measurement: 'RPM'
    filters:
      - multiply: 0.5 #fan runs according to specs 3500rpm, so need to convert the received pulses as that was max 8000

  - platform: dht
    pin: GPIO27
    model: DHT11
    temperature:
      name: "TH14_Werkbank_Temperature"
      id: th14_temp
    humidity:
      name: "TH14_Werkbank_Humidity"
      id: th14_humidity
    update_interval: 60s

#https://esphome.io/components/sensor/rotary_encoder.html
  - platform: rotary_encoder
    name: "Werkbank_Rotary_Encoder"
    pin_a: 
      number: GPIO18
      inverted: true
      mode:
        input: true
        pullup: true
    pin_b: 
      number: GPIO17
      inverted: true
      mode:
        input: true
        pullup: true
    on_clockwise:
      then:
        - logger.log: "Turned Clockwise"
        - lambda: |-
              if (id(Werkbank_Ventilator_Override).state)
              {
                //Do nothing as the override is active which is set in Home Assistant
              }
              else 
              {
              // global value will be increased by 10
              if (id(num_Fan_Set_Speed) < 100) {
              id(num_Fan_Set_Speed) += 10;
              id(pwm_output_fan).set_level(id(num_Fan_Set_Speed)/100); //set the speed level between 0 and 1 https://esphome.io/components/output/index.html
              }
              }

    on_anticlockwise:
      - logger.log: "Turned Anticlockwise"
      - lambda: |-
              if (id(Werkbank_Ventilator_Override).state)
              {
                //Do nothing as the override is active which is set in Home Assistant
              }
              else 
              {
              if (id(num_Fan_Set_Speed) > 10) {  //Below 10 the fan stops spinning due to the electrical characteristics of the fan
              // global value will be decreased by 10
              id(num_Fan_Set_Speed) -= 10;
              id(pwm_output_fan).set_level(id(num_Fan_Set_Speed)/100);
              }
              else {
                id(num_Fan_Set_Speed) = 0;
                id(pwm_output_fan).turn_off();
              }
              }
  
#https://esphome.io/components/binary_sensor/gpio
binary_sensor:
  - platform: gpio
    pin:
      number: GPIO19
      mode:
        input: true
        pullup: true
    name: "Werkbank_Rotary_Push_Sensor"
    filters:
      - delayed_on: 10ms #against debouncing
      - delayed_off: 10ms
    on_release:
      - lambda: |-
            if (id(Werkbank_Ventilator_Override).state)
              {
                //Do nothing as the override is active which is set in Home Assistant
              }
              else 
              {
              id(num_Fan_Set_Speed) = 0;
              id(pwm_output_fan).turn_off();      
              }

#button to switch between local and remote mode                   
  - platform: gpio
    pin:
      number: GPIO04
      mode:
        input: true
        pullup: true
    id: Button_Mode_Local #when not in local mode, then it runs remote mode
    name: "Werkbank_Mode"
    on_press:
      then:
        - switch.toggle: werkbank_mode_local #the momentary button sensor will switch the switch into the other position

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

#https://esphome.io/guides/automations.html?highlight=helpe
time:
  - platform: homeassistant
    id: homeassistant_time
#https://esphome.io/components/time/index.html?highlight=on_time
    on_time:
      - seconds: /10  # needs to be set, otherwise every second this is triggered!
        minutes: '*'  # Trigger every 2 minutes
        then:
          lambda: !lambda |-
            auto time = id(homeassistant_time).now();
            int t_now = parse_number<int>(id(homeassistant_time).now().strftime("%H%M")).value();
            if (id(Werkbank_Ventilator_Override).state)
              {
                //Do nothing as the override is active which is set in Home Assistant
              }
              
                 
              
            
    #end code