s.boot

(


	b = NetAddr.new("127.0.0.1", 57000);
	// Funzione che manda numeri causali che rappresentano il set_order del markov model
	~valori = [3, 4, 5, 6, 7, 8];

	~close = Routine.new({
		inf.do {
			var chosen = ~valori.choose;
			chosen.postln;
			b.sendMsg("/closeness", chosen);
			3.wait;
    }
}).play;




SynthDef(\clean, {
	arg amp, freq, dur;
	var env = Env([0, amp, 0], [dur/10, dur*9/10]);
	var in;
	in=SinOsc.ar(freq)*EnvGen.kr(env, doneAction: Done.freeSelf);
	Out.ar([0,1], in*0.05);
}).add;




OSCdef.new(\0,
	{
		arg msg;
		if( msg[4] != 0.0,{
		x=Synth.new(\clean, [\freq, msg[1].midicps, \amp, msg[2].linexp(0, 127, 0.1, 1), \dur, 2*msg[4]]);
		},{});
		postln('');
		postln(msg[1]);
		postln(msg[2]);
		postln(msg[3]);
		postln(msg[4]);
	},
	'/numbers',
	nil,
	57120
);
)

