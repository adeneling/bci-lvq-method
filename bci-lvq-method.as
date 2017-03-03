package methods 
{
	/**
	 * ...
	 * @author Maulana Yusup Abdullah
	 */
	
	import screens.classification.inLearning;
	import starling.core.Starling;
	import starling.display.Sprite;
	import flash.utils.getTimer;
	
	import feathers.controls.Alert;
	import feathers.data.ListCollection;
	
	// SQL EXECUTION
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	import flash.data.SQLResult;
	import flash.events.SQLEvent;
	import flash.events.SQLErrorEvent;
	import flash.events.SQLUpdateEvent;
	import flash.errors.SQLError;
	import flash.errors.SQLErrorOperation;
	import flash.filesystem.File;
	import starling.utils.execute;
	import database.DatabaseExecution;
	
	public class LearningVectorQuantization extends Sprite
	{
		public var upwardData:Array = new Array();
		public var downwardData:Array = new Array();
		public var fftData:Array = new Array();
		public var eegData:Array = new Array();
		public var initialUpward:Array = new Array();
		public var initialDownward:Array = new Array();
		public var data1:Array = new Array();
		public var data2:Array = new Array();
		public var learningResult:Number = new Number();
		private var distance:int;
		private var y_class:int;
		private var matching:Boolean;
		
		public var progressValue:int;
		public var textProgressValue:String = new String();
		
		public function LearningVectorQuantization() 
		{
			
		}
		
		// LEARNING WITH FFT AND LVQ
		public function learningProcess(maxEpoch:int, minError:Number, learningRate:Number, learningRateDecrement:Number,rate:int ) {
			var startingTime:Number = getTimer();
			var createStmtUp:SQLStatement = new SQLStatement();
			var createStmtDown:SQLStatement = new SQLStatement();
			var createStmtFftData:SQLStatement = new SQLStatement();
			var createStmtClass:SQLStatement = new SQLStatement();
			
			var conn:SQLConnection;
			conn = new SQLConnection();
			
			var folder:File = File.applicationDirectory;
			var db:String = "dodolipet_db.db";			
			var dbFile:File = folder.resolvePath(db);			
			conn.open(dbFile);			
			createStmtUp.sqlConnection = conn;
			createStmtDown.sqlConnection = conn;
			createStmtFftData.sqlConnection = conn;
			createStmtClass.sqlConnection = conn;
			
			createStmtUp.text = "SELECT fft_result FROM extraction INNER JOIN learning_data ON extraction.learning_data_id = learning_data.id where learning_data.target_class = 1";
			createStmtDown.text = "SELECT fft_result FROM extraction INNER JOIN learning_data ON extraction.learning_data_id = learning_data.id where learning_data.target_class = 2";
			createStmtFftData.text = "SELECT * FROM extraction";
			createStmtClass.text = "SELECT target_class FROM learning_data";
			try{ 
				createStmtUp.execute();
				createStmtDown.execute();
				createStmtFftData.execute();
				createStmtClass.execute();
				
				var resultUpwardData:SQLResult = createStmtUp.getResult();
				var resultDownwardData:SQLResult = createStmtDown.getResult();
				var resultFftData:SQLResult = createStmtFftData.getResult();
				var resultClassData:SQLResult = createStmtClass.getResult();
				
				var numResultsUpwardData:int = resultUpwardData.data.length; 
				var numResultsDownwardData:int = resultDownwardData.data.length; 
				var numResultsFftData:int = resultFftData.data.length;
				var numResultsClassData:int = resultClassData.data.length;
			} 
			catch (error:SQLError) 
			{ 
				trace("Can't Load Data!");
			}	
			
			// DECLARE FIRST BOBOT
			var initialWeight1:Object = resultUpwardData.data[0];
			var initialWeight2:Object = resultDownwardData.data[0];
			var initialWeight1Data:String = initialWeight1.fft_result;
			var initialWeight2Data:String = initialWeight2.fft_result;
			data1 = initialWeight1Data.split(",");			
			data2 = initialWeight2Data.split(",");

			var arrayIeuTehWa:Array = new Array();
			for (var j:int = 0; j < data1.length; j++) 
			{
				arrayIeuTehWa.push(data1[j]);
			}
			trace(arrayIeuTehWa);
			
			
			var tempEpoch:int = 0;
			var epoch:int = 0;
			
			try{
				while ((epoch < maxEpoch) && (learningRate > minError)) {
					for (var i:int = 2; i < numResultsFftData; i++) {						
						// LEARNING DATA
						var rowClassData:Object = resultClassData.data[i];
						var classData:int = rowClassData.target_class;
						var rowFftData:Object = resultFftData.data[i];
						var dataFft:String = rowFftData.fft_result;						
						var idDataEEG:String = rowFftData.learning_data_id;
						fftData = dataFft.split(",");
						
						distance = findDistance(data1, data2, fftData);
						
						if(distance == classData){
							if (distance == 1) {
								data1 = repairData(data1, fftData, learningRate, true);								
							}else if (distance == 2) {
								data2 = repairData(data2, fftData, learningRate, true);
							}							
						}else{
							if(distance == 1){
								data1 = repairData(data1, fftData, learningRate, false);
							}else if(distance == 2){
								data2 = repairData(data2, fftData, learningRate, false);
							}
						}
					}
					tempEpoch = epoch;
					trace("Epoch: " + epoch);
					learningRate = learningRate - (learningRateDecrement * learningRate);
					epoch++;
				}
				try 
				{
					var dbExecute:DatabaseExecution = new DatabaseExecution();
					dbExecute.getConnection();
					dbExecute.insertLearningResult(data1, data2);
					// CLEAR ARRAY
					data1.length = 0;
					data2.length = 0;
				}catch (err:Error)
				{
					trace("Cannot Insert Database");
				}
			}catch (err:Error){
				trace("Cannot Looping");
			}
			var endingTime:Number = getTimer();			
			trace("Learning Time: " + ((endingTime - startingTime) * 0.001));
			
		}// END FUNCTION
		
		public function repairData(w:Array, data:Array, learningRate:Number, matching:Boolean):Array {
			var wTemp:Array = w;			
			var i:int;
			
			if(matching == true){
				for (i = 0; i < w.length; i++) {
					wTemp[i] = (Number(w[i]) + Number(learningRate * (data[i] - w[i])));
				}
			}else if(matching == false){
				for(i=0;i<w.length;i++){
					wTemp[i] = (Number(w[i]) - Number(learningRate * (data[i] - w[i])));
				}
			}			
			return wTemp;			
		}
		
		// TESTING HEULA WA
		public function testing(w1:Array, w2:Array, data:Array, idEEGData:int):int {
			var testResult:int;
			var distance:int = 0;
			for (var j:int = 0; j < data.length; j++) 
			{
				distance = findDistance(w1, w2, data);
				if (distance == 1) {
					testResult = 1;
				}else if (distance == 2) {
					testResult = 2;
				}
			}
			return testResult;
		}
		
		// CARI JARAK
		public function findDistance(data1:Array,data2:Array,neuron:Array):int {
			var result1:Number = new Number();
			var result2:Number = new Number();
			var w1:Array = data1;
			var w2:Array = data2;
			//var y_class:int;			
			var i:int = 0;
			
			for (i=0; i <w1.length ; i++){
				result1 = result1 + Math.pow((neuron[i]-w1[i]), 2);
			}			
			result1 = Math.sqrt(result1);
			
			for (i=0; i <w2.length ; i++){
				result2 = result2 + Math.pow((neuron[i]-w2[i]), 2);
			}
			result2 = Math.sqrt(result2);
			
			if(Math.min(result1, result2) == result1){
				y_class = 1;
			}else{
				y_class = 2;
			}			
			return y_class;
		}
		
		// LEARNING WITH LVQ
		public function learningLVQ(maxEpoch:int, minError:Number, learningRate:Number, learningRateDecrement:Number, rate:int ) {
			var movingTime:int = rate;
			var startingTime:Number = getTimer();
			var createStmtUp:SQLStatement = new SQLStatement();
			var createStmtDown:SQLStatement = new SQLStatement();
			var createStmtFftData:SQLStatement = new SQLStatement();
			var conn:SQLConnection;
			conn = new SQLConnection();
			
			var folder:File = File.applicationDirectory;
			var db:String = "dodolipet_db.db";			
			var dbFile:File = folder.resolvePath(db);			
			conn.open(dbFile);			
			createStmtUp.sqlConnection = conn;
			createStmtDown.sqlConnection = conn;
			createStmtFftData.sqlConnection = conn;
			
			createStmtUp.text = "SELECT eeg_data FROM learning_data where target_class = 1";
			createStmtDown.text = "SELECT eeg_data FROM learning_data where target_class = 2";
			createStmtFftData.text = "SELECT * FROM learning_data";
			try{ 
				createStmtUp.execute();
				createStmtDown.execute();
				createStmtFftData.execute();
				
				var resultUpwardData:SQLResult = createStmtUp.getResult();
				var resultDownwardData:SQLResult = createStmtDown.getResult();
				var resultData:SQLResult = createStmtFftData.getResult();
				
				var numResultsUpwardData:int = resultUpwardData.data.length; 
				var numResultsDownwardData:int = resultDownwardData.data.length; 
				var numResultsData:int = resultData.data.length;
			} 
			catch (error:SQLError) 
			{ 
				trace("Can't Load Data!");
			}	
			
			// DECLARE FIRST BOBOT
			var initialWeight1:Object = resultUpwardData.data[0];
			var initialWeight2:Object = resultDownwardData.data[0];
			var initialWeight1Data:String = initialWeight1.eeg_data;
			var initialWeight2Data:String = initialWeight2.eeg_data;
			var tempData1:Array = new Array();
			var tempData2:Array = new Array();
			tempData1 = initialWeight1Data.split(",");
			tempData2 = initialWeight2Data.split(",");
			if (movingTime == 512) {
				for (var k:int = 0; k <= 511; k++) 
				{
					data1.push(tempData1[k]);
					data2.push(tempData2[k]);
				}
			}else {
				data1 = initialWeight1Data.split(",");
				data2 = initialWeight2Data.split(",");
			}
			
			
			var tempEpoch:int = 0;
			var epoch:int = 0;
			
			try{
				while ((epoch < maxEpoch) && (learningRate > minError)) {
					for (var i:int = 2; i < numResultsData; i++) {						
						// LEARNING DATA
						var rowData:Object = resultData.data[i];
						var dataEEGRaw:String = rowData.eeg_data;						
						var idDataEEG:String = rowData.id;
						var classData:int = rowData.target_class;
						var tempEegData:Array = new Array();
						tempEegData = dataEEGRaw.split(",");
						if (movingTime == 512) {
							for (var j:int = 0; j <= 511; j++) 
							{
								eegData.push(tempEegData[j]);
							}
						}else {
							eegData = dataEEGRaw.split(",");
						}
						
						distance = findDistance(data1, data2, eegData);
						
						if(distance == classData){
							if(distance == 1){
								data1 = repairData(data1, eegData, learningRate, true);
							}else{
								data2 = repairData(data2, eegData, learningRate, true);
							}
						}else{
							if(distance == 1){
								data1 = repairData(data1, eegData, learningRate, false);
							}else{
								data2 = repairData(data2, eegData, learningRate, false);
							}
						}						
					}
					tempEpoch = epoch;
					trace("In Epoch: " + epoch);						
					learningRate = learningRate - (learningRateDecrement * learningRate);
					epoch++;
				}
				trace("w1.length: " + data1.length);
				trace("w2.length: " + data2.length);
				try 
				{
					var dbExecute:DatabaseExecution = new DatabaseExecution();
					dbExecute.getConnection();
					dbExecute.insertLearningResult(data1, data2);
					// CLEAR ARRAY
					data1.length = 0;
					data2.length = 0;
				}catch (err:Error){
					trace("Cannot Insert Database");
				}				
			}catch (err:Error){
				trace("Cannot Looping");
			}			
			var endingTime:Number = getTimer();			
			trace("Learning Time: " + ((endingTime - startingTime) * 0.001));			
		}// END FUNCTION
	}
}