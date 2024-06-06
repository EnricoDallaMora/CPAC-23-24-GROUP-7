from pathlib import Path
from typing import List
import mido
import pyOSC3
import time
from my_chain_fe import VariableLengthMarkovChain
from threading import Thread

max_order=8
set_order = None
dataset_directory=Path("./maestro-v3.0.0/test")


#ENCODE METHOD

def encode(file: mido.MidiFile) -> List[str]:
    notes = []
    velocities = []
    times = []

    for message in mido.merge_tracks(file.tracks):
        if message.type != "note_on":
            continue

        notes.append(int(message.note))
        velocities.append(int(message.velocity))
        times.append(int(message.time))

    return notes, velocities, times


# Function to set the tempo and the bpm of the dataset midi files 

def setup_time(file: mido.MidiFile):
    for message in file:
        if message.type == 'set_tempo':
            tempo = message.tempo
            bpm = mido.tempo2bpm(tempo)
            break

    return tempo, bpm



#GENERATE MODEL

dataset_notes = []
dataset_velocities = []
dataset_times = []
for filename in dataset_directory.iterdir():
    with mido.MidiFile(filename) as file:
        notes, vel, times = encode(file)

    dataset_notes.append(notes)
    dataset_velocities.append(vel)
    dataset_times.append(times)

    print(f"Processed {filename}")


#set tempo, bpm and ticks per beat
    
first_file_midi = next(dataset_directory.iterdir())
with mido.MidiFile(first_file_midi) as file:
    tempo, bpm = setup_time(file)
    ticks_per_beat = file.ticks_per_beat

print(tempo, bpm, ticks_per_beat)



# Function to menage the received OSC messages
def handle_message(address, tags, data, client_address):
    global set_order
    set_order = data[0]
    print(f"Ricevuto messaggio da {address}: {set_order}")


# Function to run the server in a separated thread
def run_server():
    
    server = pyOSC3.OSCServer(("127.0.0.1", 57000))
    server.addMsgHandler("/closeness", handle_message)

    print(f"In ascolto")
    
    # Run the server
    server.serve_forever()

server_thread = Thread(target=run_server)
server_thread.start()


markov_chain_notes = VariableLengthMarkovChain(max_order, dataset_notes)
markov_chain_velocity = VariableLengthMarkovChain(max_order, dataset_velocities)
markov_chain_time = VariableLengthMarkovChain(max_order, dataset_times)




#GENERATE NOTES

client = pyOSC3.OSCClient()
client.connect( ( '127.0.0.1', 57120 ) )
state_notes = tuple(dataset_notes[0][0:set_order])
state_velocity = tuple(dataset_velocities[0][0:set_order])
state_time = tuple(dataset_times[0][0:set_order])


while True:
    print(set_order)
    next_state_notes = markov_chain_notes.generate(state_notes, set_order)
    next_state_velocity = markov_chain_velocity.generate(state_velocity, set_order)
    next_state_time = markov_chain_time.generate(state_time, set_order)
    #update current state with next state requires the tuple to be converted to list,
    #manipulated and converted back to tuple
    update_state_notes=list(state_notes)
    update_state_notes.pop(0)
    update_state_notes.append(next_state_notes)
    state_notes=tuple(update_state_notes)

    update_state_velocity=list(state_velocity)
    update_state_velocity.pop(0)
    update_state_velocity.append(next_state_velocity)
    state_velocity=tuple(update_state_velocity)

    update_state_time=list(state_time)
    update_state_time.pop(0)
    update_state_time.append(next_state_time)
    state_time=tuple(update_state_time)
    #control generation/printing flow (currentlty every 1 second)
    print("Note: "+str(next_state_notes)+" velocity: "+str(next_state_velocity)+" time: "+str(next_state_time))

    msg = pyOSC3.OSCMessage()
    msg.setAddress("/numbers")
    out=[next_state_notes, next_state_velocity, next_state_time]
    msg.append(out)
    
    #compute the delta time, it's the time that should pass between the last note played and the current note
     
    delta_time = mido.tick2second(next_state_time, ticks_per_beat, tempo)
    print(delta_time)
    
    time.sleep(delta_time)

    client.send(msg)

    
    
    

