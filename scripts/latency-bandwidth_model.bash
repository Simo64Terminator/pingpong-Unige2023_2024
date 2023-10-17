#!/bin/bash

# Se l'utente inserisce dei parametri dopo la chiamata dello script, esso non parte
if [[ $# != 0 ]]; then
	printf "Error: Unexpected parameters\n";
	exit 1;
fi


# Dichiariamo un array per poter avere più facilità nella creazione dei grafici
declare -a protocol=("udp" "tcp")


# Facciamo un ciclo che crei due plot usando gli elementi di protocol (udp e tcp)
for indexProtocol in "${protocol[@]}"
do
	# Prepariamo due variabili per i Throughput medi in due istanti di tempo diversi
	declare Thput1
	declare	Thput2

	# Prepariamo due variabili per salvare la dimensione dei messaggi in due istanti di tempo diversi
	declare minMessSize
	declare maxMessSize


	#/////////////////////////////////////////////////////////////////////////


	# Recupero l'infomazione all'inizio ed alla fine dei file *_throughput.dat, eliminando i dati che non mi servono
	Thput1=$(head -n 1 ../data/"$indexProtocol"_throughput.dat | cut -d ' ' -f3) # cut scritto in questo modo usa ' ' come delimitatore fra gli elementi della stringa, dopodichè scegliamo l'elemento da mantenere (in questo caso f3)
	Thput2=$(tail -n 1 ../data/"$indexProtocol"_throughput.dat | cut -d ' ' -f3)

	# Stesso ragionamento
	minMessSize=$(head -n 1 ../data/"$indexProtocol"_throughput.dat | cut -d ' ' -f1)
	maxMessSize=$(tail -n 1 ../data/"$indexProtocol"_throughput.dat | cut -d ' ' -f1)


	#/////////////////////////////////////////////////////////////////////////
	
	
	# Sezione dedicata per eliminare le notazioni scientifiche 
	# (più tipiche in una macchina nativa linux) (es 3.78998e+06)
	
	declare exponent

	# Eliminazione esponenziali da minMessSize
	if [[ $minMessSize == *"e+"* ]]; then
		exponent=$(echo $minMessSize | cut -d '+' -f2)	
		minMessSize=$(echo $minMessSize | cut -d 'e' -f1)

		minMessSize=$(echo "$minMessSize*(10^$exponent)" | bc)
	fi
	
	# Eliminazione esponenziali da maxMessSize
	if [[ $maxMessSize == *"e+"* ]]; then
		exponent=$(echo $maxMessSize | cut -d '+' -f2)	
		maxMessSize=$(echo $T| cut -d 'e' -f1)

		maxMessSize=$(echo "$maxMessSize*(10^$exponent)" | bc)
	fi

	# Eliminazione esponenziali da Thput1
	if [[ $Thput1 == *"e+"* ]]; then
		exponent=$(echo $Thput1 | cut -d '+' -f2)	
		Thput1=$(echo $Thput1 | cut -d 'e' -f1)

		Thput1=$(echo "$Thput1*(10^$exponent)" | bc)
	fi
	
	# Eliminazione esponenziali da Thput2
	if [[ $Thput2 == *"e+"* ]]; then
		exponent=$(echo $Thput2 | cut -d '+' -f2)	
		Thput2=$(echo $Thput2 | cut -d 'e' -f1)

		Thput2=$(echo "$Thput2*(10^$exponent)" | bc)
	fi


	#/////////////////////////////////////////////////////////////////////////


	# Dati per l'utente, output
    echo
    echo ----"$indexProtocol"----
    echo Size Min: "$minMessSize" 
    echo Size Max: "$maxMessSize"
    echo Throughput Min: "$Thput1"
    echo Throughput Max: "$Thput2"


	#/////////////////////////////////////////////////////////////////////////


	# Dichiaro ritardo min e max, e vi calcolo al suo interno il delay usando la formula inversa "delay = msg_size/T"
	# bc è una calcolatrice utilizzabile da terminale, ed ha la facoltà di decidere la scala da usare, bisogna definire le variabili (ed il loro valore) per poi usarli nel calcolo finale
	declare minDelay
	declare maxDelay
	
	minDelay=$(echo "scale=5; $minMessSize/$Thput1" | bc)
	maxDelay=$(echo "scale=5; $maxMessSize/$Thput2" | bc)

	
	echo Delay Min: "$minDelay"
    echo Delay Max: "$maxDelay"
	
	
	# Dichiaro le variabili myLatency0 e myBandwidth secondo le formule definite su aulaweb
	declare myL0
	declare myB
	myL0=$(echo "scale=5; ((($minDelay*$maxMessSize)-($maxDelay*$minMessSize))/($maxMessSize-$minMessSize))" | bc)
	myB=$(echo "scale=5; (($maxMessSize-$minMessSize)/($maxDelay-$minDelay))" | bc)
	
	
	echo myLatency0: "$myL0"
	echo myB: "$myB"
	
	
	# Mi premuro di cancellare vecchi grafici nel caso ci siano
	declare graphName
	graphName=$(echo "../data/${indexProtocol}_latency_bandwidth_model.png")
	
	if [[ -f "$graphName" ]] ; then
		rm "$graphName"
	fi
	
	# Creo il plot lbf() è il calcolo per il modello Banda-Latenza = "D(n) = L0 + N/B" => "x / ($myL0 + x / $myB)"
	gnuplot <<-endGnuplot
        set term png size 1000, 1000 
        set output "../data/${indexProtocol}_latency_bandwidth_model.png"
        set logscale y 10
        set logscale x 2
        set xlabel "msg size (B)"
        set ylabel "throughput (KB/s)"
        lbf(x) = x / ($myL0 + x / $myB)
        plot "../data/${indexProtocol}_throughput.dat" using 1:3 title "${indexProtocol} ping-pong Throughput" \
            with linespoints, \
        lbf(x) title "Latency-Bandwidth model with L=${myL0} and B=${myB}" \
            with linespoints
endGnuplot

done
