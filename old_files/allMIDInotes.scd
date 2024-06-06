(
s.waitForBoot {
	    // Dictionary to store synths
    var synthDictionary = Dictionary.new;

	b = NetAddr.new("127.0.0.1", 57000);
	// Funzione che manda numeri causali che rappresentano il set_order del markov model
	~valori = [1, 2, 3, 4, 5];
	~close = Routine.new({
		inf.do {
			var chosen = ~valori.choose;
			chosen.postln;
			b.sendMsg("/closeness", chosen);
			3.wait;
    }
}).play;


    // Define SynthDef
    SynthDef(\midiSynth, { |freq = 440, amp = 1|
        var sig;
        sig = SinOsc.ar(freq) * amp;
		Out.ar([0, 1], sig);
    }).add;




    // Function to instantiate synths for all MIDI notes
    {
        var synth;

        (0..127).do { |midiNote|
            // Instantiate synth for each MIDI note
            synth = Synth(\midiSynth, [
                \freq, midiNote.midicps,
                \amp, 0 // Start with 0 amplitude
            ]);

            // Store synth in the dictionary with MIDI note as key
            synthDictionary.put(midiNote, synth);
        };
    }.value;




    // Define OSC responder for MIDI notes and velocities
    OSCdef(\midiNoteVel, { |msg|
        var midiNote = msg[1];
        var velocity = msg[2];

        // Retrieve the synth corresponding to the MIDI note
        var synth = synthDictionary.at(midiNote);

        // Set the amplitude based on velocity
		synth.set(\amp, velocity/(127*3));
		postln("note="+msg[1]);
		postln("vel="+msg[2]);
    }, '/numbers');
	/*
    // Start OSCFunc for receiving MIDI note and velocity messages
    OSCFunc({ |msg, time, addr, recvPort|
        msg.postln; // Print incoming OSC message for debugging
        OSCdef(\midiNoteVel).action(msg);
    }, '/midiNoteVel');
	*/
};
)
