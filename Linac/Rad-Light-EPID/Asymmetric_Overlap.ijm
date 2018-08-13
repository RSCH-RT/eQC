// -------------------------------------------------------------------------------------------------------------------------------------------
//  Initial macro by: Sarah Bailey 17 Dec 2013  - option to invert images if background is dark added by Matt Bolt 29 Aug 2014
//
//  Revision 1.2 by JP - CU calibration applied to images prior to analysis 
// -------------------------------------------------------------------------------------------------------------------------------------------
//	Results X,Y display rather than North South
//	At Coll 90, North (G) = X2, South (T) = X1, East (B) = Y1, West (A) = Y2


// ********************* global variables ***********************
//  can be seen (edited) by all functions in this macro
var maxPixValue;
var pWidth;
var pHeight;
var arrayImageID;
var arrayImageName;
var myFolder;
var myLinac;
var intEnergy;
var intSSD;
var strDateImage;
var meanImage;
var pLow;  // used in mini profile of overlap region
var pHigh;
var xArr;
var yArr;
var myLen;
// -------------------------------------------------------------------------------------------------------------------------------------------
//				MAIN MACRO
// -------------------------------------------------------------------------------------------------------------------------------------------
macro "AssymAnalysis" {

version = "1.3";
update_date = "04 April 2017 by JP";

	requires("1.47p");
	myLinac = getArgument() ;
	if(myLinac == "") {
		myLinac = "Select";
	}

	// Show a dialog to user so that they know the macro is running

	if (nImages != 0) {
	   exit("Oops, please close all images before running this macro! ");
	} 

	lstLinac = newArray("LA1","LA2","LA3","LA4","LA5", "LA6", "Red-A", "Red-B", "Select");		

	Dialog.create("Macro Opened");
	Dialog.addMessage("EPID QC Asymmetric Image Analysis");
	Dialog.addMessage("Version: " + version);
	Dialog.addMessage("Last Updated: " + update_date);
	Dialog.addMessage("");
	Dialog.addMessage("This is an automated process as folows:");
	Dialog.addMessage("You will be promted to select the folder containg the 4 asymmetric images.");	
	Dialog.addMessage("Results appear in the Log window");
	Dialog.addMessage("");
	//Dialog.addMessage("Linac: "+myLinac);
	Dialog.addChoice("             Linac:", lstLinac,myLinac);

	Dialog.addMessage("                                    ***** Click OK to start ******");
	Dialog.show();

	myLinac = Dialog.getChoice();

   	myDirectory = "G:\\Shared\\Oncology\\Physics\\Linac Field Analysis\\"+myLinac+"\\ ";
   	call("ij.io.OpenDialog.setDefaultDirectory", myDirectory);
   	call("ij.plugin.frame.Editor.setDefaultDirectory", myDirectory);

	print(myDirectory);

	myFolder = getDirectory("Choose Image File Directory ");
	list = getFileList(myFolder);
	setBatchMode(true);

	if (list.length != 4) {
	         exit("WARNING: Only 4 image files may exist in the selected folder (there are currently "+list.length+"). Please make this so and re-run macro.");
	}

// removes any previous calibration - affects the X-ray field results

	myCF = 0.039;

	for (k=0; k<list.length; k++) {
		showProgress(k/3);

		open(myFolder+list[k]);
	   	myID = getImageID(); 	  
		strName=getTitle(); 			// image name of newscaled image
		
		run("32-bit");
		ConvertPVtoCU(myID);
		

		// extract DICOM Image data:
		intEnergy = parseInt(getInfo("0018,0060")) / 1000;
		strDateImage = getInfo("0008,0023");
		intSSD = parseInt(getInfo("3002,0026")) / 10;

		run("Calibrate...", "function=None unit=[Gray Value] text1=[ ] text2= global show");

		// rescale the original image if it is from old imager with only 512 x 384 pixels i.e. LA5/6
		pWidth = getWidth();
		pHeight = getHeight();
	
		if (pWidth == 512) {
			myCF = 0.0392;
		   	myOldID = getImageID(); 	  
			strNew = "Scaled"+k+1+".dcm";
			run("Scale...", "x=2 y=2 width="+pWidth+" height="+pHeight+" interpolation=Bilinear average create title="+strNew);

			selectImage(myOldID);  // close original image as we don't need it any more
			run("Close"); 

			selectImage(strNew);  
		   	myID = getImageID(); 	  
		}

		arrayImageID = Array.concat(arrayImageID, myID);
		arrayImageName = Array.concat(arrayImageName, strName);
		
	}

	// make sure we have current image's width and height
	pWidth = getWidth();
	pHeight = getHeight();

	printHeader();

// call function combineImages();

	combineImages();
	

// *** This part to position the mean ROIs has been adapted as LA6 has a 40x40cm imager (1190px) and so the positions of the 10x10 feilds varies.
// *** The positoins has of the ROIs for all imageers has been slightly adjusted to make them more central.

//	xV1 = 330;		// vertical profiles where x = 330 and x = 690 on a 1024 image
//	xV2 = 690;
//	yH1 = 200;		// horizontal profiles where y =200 and y = 560 on a 1024 image
//	yH2 = 560;


	if (pWidth ==1190) {
		xV1 = 420;
		xV2 = 780;
		yH1 = 420;
		yH2 = 780;
	} else {
		xV1 = 390;
		xV2 = 650;
		yH1 = 260;
		yH2 = 520;
	}


// find the intersections should be 70-130% of mean
// calc average of 4 ROIs - one per quadrant	
// makeRectangle(x, y, width, height), where x,y are coordinates of the upper left corner

	selectImage(arrayImageID[5]);  		// make sure we still have the correct image

// ******* This section added by Matt Bolt on 29 Aug 2014 to allow user to invert image if required (e.g. for Red-A and Red-B) **************************
// Background of image should be white, with dark irradiated areas for correct analysis


	setBatchMode("exit & display");	// displays all open images	// need to show image for user to amke decision
	
	
// ********************************************************************************************************************************************************

	////getStatistics(area, mean, min, max, std, histogram);	
	////maxPixValue = max;
	meanImage = findMean(arrayImageID[5]);
	
	centreX = pWidth / 2;
	centreY = pHeight / 2;

	////xArr = newArray(4);
	////yArr = newArray(4);

	////absArrayX= newArray(4);
	////absArrayY = newArray(4);

	// Intersection North, South, East, West (up/down as view screen) horizontal: Y = constant 
	// Coll = 90, North (G) = X2, South (T) = X1, East (B) = Y1, West (A) = Y2
	// Coll = 0, North=Y2, South=Y1, East=X2, West=X1

	// getOverlap fills xArr and yArr arrays

	myLen = 25; 		//length of overlap line = 2 x myLen - also used in getOverlap function
	
	resN = getOverlap(centreX-myLen, centreY-100, centreX+myLen, centreY-100, meanImage, "X", 0); // N, X2	
	resS =getOverlap(centreX-myLen, centreY+100, centreX+myLen, centreY+100, meanImage, "X", 2);  // S, X1
	resE = getOverlap(centreX+100, centreY-myLen, centreX+100, centreY+myLen, meanImage, "Y", 0); // E, Y1	
	resW = getOverlap(centreX-100, centreY-myLen, centreX-100, centreY+myLen, meanImage, "Y", 2); // W, Y2

		
	print("North, South East, West refer to image orientation as you look at the screen");
	print("For Coll 90:");
	print("Y (T): "+resS+"%");
	print("Y (G): "+resN+"%");
	print("X (B): "+resE+"%");
	print("X (A): "+resW+"%");
	print("\n");	

	print("Result Y: "+CalcMax(resN,resS)+"%");
	print("Result X: "+CalcMax(resE,resW)+"%");
	print("\n");	
	print("Tolerance: 70%-130%");	
	print("-------------------------------------------------------------");

//	close all temp images
	
	setBatchMode("exit & display");	// displays all open images - hopefully, just the resultant image
	saveResults();
	selectWindow("Log");


} // ************************ End Main Macro 
// ----------------------------------------------------------------------------------------------------------------

// ----------------------------------------------------------------------------------------------------------------
//			FUNCTIONS IN USE 
// ----------------------------------------------------------------------------------------------------------------

//  **************************** FUNCTION COMBINE IMAGES ******************************************
function combineImages() {

	// Combine the 4 images - can only add two at a time and close interim images

	imageCalculator("Add create 32-bit", arrayImageID[1], arrayImageID[2]);
	temp1 = getImageID();

	imageCalculator("Add create 32-bit", arrayImageID[3], arrayImageID[4]);
	temp2 = getImageID();

	imageCalculator("Add create 32-bit", temp1, temp2);
	imageR = getImageID();
	run("Calibrate...", "function=None unit=[Gray Value] text1= text2= show");

	selectImage(temp1);  	// close these temp images
	run("Close"); 

	selectImage(temp2);  	// close these temp images
	run("Close"); 

	arrayImageID = Array.concat(arrayImageID, imageR);
	arrayImageName = Array.concat(arrayImageName, "Combined");

	selectImage(arrayImageID[1]);close();
	selectImage(arrayImageID[2]);close();
	selectImage(arrayImageID[3]);close();
	selectImage(arrayImageID[4]);close();
	
	
}
// end function combineImages


//  **************************** FUNCTION GET OVERLAP ******************************************
function getOverlap(x1, y1, x2, y2, imMean, isX, arrayPos){
	
	makeLine(x1, y1, x2, y2);
	run("Line Width...", "line=5");		//average across 5 pixels when use line size of 5
	myProfile = getProfile();		
	Array.getStatistics(myProfile,min, max);
	
	//meanMin = min;
	//meanMax = max;
	endAt = (2* myLen) -1;

	// Average profile
	avProfile = newArray(lengthOf(myProfile));
	
	// copy array before averaging as the first and last elements cant be averaged, which is likely to cause issues with analysis
	for(i=0;i<lengthOf(myProfile);i++) avProfile[i]=myProfile[i];

	for(i=1;i<lengthOf(myProfile)-2;i++) {
		avProfile[i] = (myProfile[i-1] + myProfile[i] + myProfile[i+1])/3;
	}

	maxDiffToMean=0;
	for (i=1; i<lengthOf(myProfile)-2; i++) {
		if (abs(avProfile[i]-imMean) > maxDiffToMean) {			
   	    		maxDiffToMean = abs(avProfile[i]-imMean);
			maxDevIndex=i;
		}
	}
	
	normalisedMaxDiff = 100*(avProfile[maxDevIndex]/imMean);	
	return Round(normalisedMaxDiff,1);
	}

} // End of Function

//  **************************** FUNCTION FIND MEAN ******************************************
function findMean(myImageID){

	selectImage(myImageID);  // ROI normally drawn on combined image

	pxROI = 50; 	// determines the size and location of ROI - i.e. 50 pixels from edge, 100 pixels square for 1024 image

	makeRectangle(xV1-pxROI, yH1-pxROI, 2*pxROI, 2*pxROI);
	getRawStatistics(area,mean);
	ROIMean = mean;

	makeRectangle(xV2-pxROI, yH1-pxROI, 2*pxROI, 2*pxROI);
	getRawStatistics(area,mean);
	ROIMean = ROIMean +mean;

	makeRectangle(xV1-pxROI, yH2-pxROI, 2*pxROI, 2*pxROI);
	getRawStatistics(area,mean);
	ROIMean = ROIMean +mean;

	makeRectangle(xV2-pxROI, yH2-pxROI, 2*pxROI, 2*pxROI);
	getRawStatistics(area,mean);
	ROIMean = (ROIMean +mean)/4;
	return ROIMean;

} // End of Function Find Mean


// ***************************** FUNCTION PRINT HEADER ************************************
function printHeader(){

	strDate = getMyDate();

	print ("\\Clear");
	print("-------------------------------------------------------------");
	print("      Assymmetric Image Analysis using EPID");
	print("-------------------------------------------------------------");
	print("Images Analysed:");
	print(myFolder);
	print("Image Date: "+strDateImage);
	print("Analysis Date: "+strDate);
	print("Macro Version:"+version);
	print("Linac: "+myLinac);
	print("Energy: "+intEnergy+"MV");
	print("SSD: "+intSSD+"cm");
	print("-------------------------------------------------------------");
	print("Ratios of intersection to image mean: ");	
	print("\n");	

}  // End Function


// ************************ FUNCTION SAVE RESULTS *******************************************
function saveResults(){

	// Add Comments & Save Results	

	Dialog.create("Comments");							//	Allows user to insert comments if required. Default is "Results OK" These are then added to Log
	Dialog.addMessage("Add any Comments in the Box Below");
	Dialog.addString("Comments:", "None",40);
	Dialog.addMessage("");
	Dialog.addString("Analysis Performed by:", "",10);
	Dialog.addMessage("Click OK to Continue");
	Dialog.show();

	print("\n");
	print("Comments:"+Dialog.getString());
	print("Analysis Performed by:" + Dialog.getString());
	print("\n");
	print("-------------------------------------------------------------");
	
	Dialog.create("~~ Save Results ~~");		//	Asks user if they want to save results (as a text file). If they select cancel, the macro wil exit, therefore the save will not occur.
	Dialog.addMessage("  Save the Results?      ");
	Dialog.show();

	selectWindow("Log");				//	Get data from log window for transfer to Text window to save
	contents = getInfo();

	FileExt = ".txt";
	title1 = strDateImage+"-"+myLinac+"-"+intEnergy+"-AsymResults" + FileExt+ FileExt;	//	Title of log window is filename without extension as defined at start.
	title2 = "["+title1+"]";							//	Repeat
	f = title2;
	if (isOpen(title1)) {
		print(f, "\\Update:");
		selectWindow(title1); 					//	clears the window if already one opened with same name
	} else {
		run("Text Window...", "name="+title2+" width=72 height=60");
	}
	setLocation(screenWidth()-50,screenHeight()-50);			//	Puts window out of sight
	print(f,contents);
	saveAs("Text",myFolder+title1);
	run("Close");	

} // End of Function

//  **************************** FUNCTION GET DATE ******************************************
function getMyDate() {

	arrMonth = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	strDate = ""+dayOfMonth+"-"+arrMonth[month]+"-"+year;
	return strDate;

  } // End Function



// ************************** FUNCTION CONVERT PV TO CU ***************************************
function ConvertPVtoCU(id) {
	selectImage(id);
	intercept = getInfo("0028,1052"); // get the slope and intercept values from the DICOM file.
	slope = getInfo("0028,1053");
	run("Multiply...", "value=&slope"); // apply the slope and intercept to the pixel values.
	run("Add...", "value=&intercept"); // slope should be applied first to ensure correctly applying linear scaling
}

function CalcMax(a,b) {
	if(abs(a-100)>=abs(b-100)) {
		return a;
	} else {
		return b;
	}
}

function Round(x,n) {
	return round(x*pow(10,n))/pow(10,n);
}
