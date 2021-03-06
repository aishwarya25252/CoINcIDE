

#pre-processing the curatedOvarianData package (this was completed in 2015.)
#Note that the processing functions had to be a bit different than the breast
#cancer datasets because the curatedOvarianData authors did not provide quite
#as many R-level data access functions.
library("Biobase")
library("Coincide")
library("curatedOvarianData")
datasetNames <- data(package="curatedOvarianData")
datasetNames <- datasetNames[3]$results[,"Item"]

#NOTE: I found it easier to just untar the package myself and access the 
#data files myself for pre-processing.
#Change these paths to your own:
#first one is where downloaded curatedOvarianData package - need /data file:
local_download_path <- "/home/kplaney/R/x86_64-redhat-linux-gnu-library/curatedOvarianData/data/" 
saveDirGlobal <- "/home/kplaney/ovarian_analysis/"
saveDir_20 <- "/home/kplaney/ovarian_analysis/withTop20Genes"
saveDir_no20 <- "/home/kplaney/ovarian_analysis/notTop20Genes"
outputFile <- "/home/kplaney/ovarian_analysis/ovarian_proc_messages.txt"

#odd way to get a dataset list...I just downloaded the source file
#and pull out their code.
#hmmm...is this the case for all genes?? WTF?
expandProbesets <- function (eset, sep = "///"){
  x <- lapply(featureNames(eset), function(x) strsplit(x, sep)[[1]])
  eset <- eset[order(sapply(x, length)), ]
  x <- lapply(featureNames(eset), function(x) strsplit(x, sep)[[1]])
  idx <- unlist(sapply(1:length(x), function(i) rep(i, length(x[[i]]))))
  xx <- !duplicated(unlist(x))
  idx <- idx[xx]
  x <- unlist(x)[xx]
  eset <- eset[idx, ]
  #Katie's notes: featureNames is from Biobase, for eset objects.
  featureNames(eset) <- x
  eset
}


#locally:
#data(list=data(package=package.name)[[3]][,3])
#strEsets <- ls(pattern="^.*_eset$")
#ON SERVER: just download the tarbell to get package, code
#cd /home/kplaney/R/x86_64-redhat-linux-gnu-library
#sudo wget http://www.bioconductor.org/packages/release/data/experiment/src/contrib/curatedOvarianData_1.3.5.tar.gz
#tar xvzf curatedOvarianData_1.3.5.tar.gz
 strEsets <- list.files(local_download_path)
# #datalist is a text file...shouldn't be any other text files in this directory, only .rda files.

 #only want rda datasets
  strEsets <- strEsets[grep("rda",strEsets)]
 
# library("limma")
# names(strEsets) <- strsplit2(strEsets,split=".rda")[,1]
# #now load all of this data. equivalent of data() call above if can install package.
# #is having trouble reading from a connection?? what's up...
# #WTF..may have to manually step through this one..
# #weird...now suddently dataset 16 isn't working? why only THIS one?
# #makes me wonder if there is a space issue on the server.
# #I had to re-download the datasets...
for (strEset in strEsets){
  #loading each dataset:
  load(paste0(local_download_path,strEset))
  
}
#now call strEset again like above:
strEsets <- ls(pattern="^.*_eset$")

##now back to common code for server or local computer:

#UBD///GABBR1 in final output...
esets <- list()
for (strEset in strEsets){
  
  eset <- get(strEset)
  ##Split out rows without unique gene name
  eset <- expandProbesets(eset, sep = "///")
  if(length(grep("///",rownames(exprs(eset))))>0){
    
    stop("Not collapsing probes correcting.")
  }
  esets[[strEset]] <- eset
  
}



#pData(esets) already contains survival data.

#remove the extra TCGA datasets
#TCGA.RNASeqV2_eset                           Integrated genomic analyses of ovarian carcinoma.
#TCGA.mirna.8x15kv2_eset                      Integrated genomic analyses of ovarian carcinoma.
#TCGA_eset                                    Integrated genomic analyses of ovarian carcinoma.
indicesRemove <- na.omit(match(c("TCGA.RNASeqV2_eset","TCGA.mirna.8x15kv2_eset"),names(esets)))
esets <- esets[-indicesRemove]

#save for easier access next time:
#saveRDS(esets, file="/home/kplaney/curatedOvarianData_esetList.rds",compress=TRUE)
#remove any healthy samples. do this for ALL studies in case some have healthy tissue.
#for example: TCGA has some normal samples
table(pData(esets[["TCGA_eset"]])[,"batch"],pData(esets[["TCGA_eset"]])[,"sample_type"])
indicesRemove <- c()

for(e in 1:length(esets)){
  
  #choose only primary tumor samples.
  pDat <- pData(esets[[e]])[which(pData(esets[[e]])["sample_type"]=="tumor"),]
  expr <- exprs(esets[[e]])[ ,which(pData(esets[[e]])["sample_type"]=="tumor")]
  
  #if no samples left: remove
  if(ncol(expr)==0){
    
    indicesRemove <- append(indicesRemove,e)
    
  }else{
    
    exprs(esets[[e]]) <- expr
    pData(esets[[e]]) <- pDat
    protocolData(esets[[e]])@data <- data.frame(row.names=colnames(exprs(esets[[e]])))
    #check: make sure is still a valid object
    validObject(esets[[e]])
    
  }
  
}
message(paste("dataset indices to remove : ",indicesRemove))
#gut check: in TCGA, should be only tumor samples now!
if(any(unique(pData(esets[["TCGA_eset"]])[,"sample_type"]) != "tumor")){
  
  stop("\nNormal filtering appeared to not work.")
  
}

#check? any duplicated samples?
#it looks like unique_patient_ID ids duplicated samples, NOT the actual expression colnames?
#a little annoying - re-label the colnames to be this unique ID, if duplicated samples are found
#but esets can't have duplicated column names.
#in the end, looks like no samples were duplicated? 
for(e in 1:length(esets)){
  
  if(!all(is.na(pData(esets[[e]])[ ,"unique_patient_ID"]))){
    #for certain datasets: this is actually all NA values. so don't use then!
    if(any(duplicated(pData(esets[[e]])[,"unique_patient_ID"]))){
      
      #if(any(duplicated(colnames(exprs(esets[[e]]))))){
      
      
      message(paste0("Duplicated samples in study ",names(esets)[e]))
      
    }
    
  }
  
}

#something to think about later: filter by primary site? 
head(pData(esets[["TCGA_eset"]])[,"primarysite"])


#}
#want very lowly varying genes to be removed for Combat.
#featureDataFieldName: must match the gene symbol column title for these esets.
esets <- procExprSetList(exprSetList=esets,outputFileDirectory=saveDirGlobal,
                                  minVar=.001,featureDataFieldName="gene",uniquePDataID="unique_patient_ID")

#look at batches - looks like the only compress=TRUE batches (besides machine runs)
#are in the TCGA dataset.
for(e in 1:length(esets)){ 
  
  if(!all(is.na(pData(esets[[e]])[,"batch"]))){
    
    cat("\n",names(esets)[e]," contains labeled batches")
    cat("\n",unique(pData(esets[[e]])[,"batch"],"\n"))
    
  }
  
}



#only split up TCGA into batches
#na.omit: if any NA batch variables, then unique will return one "NA" 
TCGAbatches <- na.omit(unique(pData(esets[["TCGA_eset"]])[,"batch"]))
#any samples with NA batch? these will be thrown out.
which(is.na(pData(esets[["TCGA_eset"]])[,"batch"]))
#let's see if batches seem to have uneven distributions of known subtypes
#and/or grade...that will make me hesitant to use batch correction.
#hmm...so most are serious?
table(pData(esets[["TCGA_eset"]])[,"batch"],pData(esets[["TCGA_eset"]])[,"histological_type"])
unique(pData(esets[["TCGA_eset"]])[,"histological_type"])
#yep...only 2 are NA, rest are serous
length(which(is.na(pData(esets[["TCGA_eset"]])[,"histological_type"])))
#this matches the Nature paper saying the samples are only serous: http://www.nature.com/nature/journal/v474/n7353/full/nature10166.html

#and predominantly late-stage for all batches
table(pData(esets[["TCGA_eset"]])[,"batch"],pData(esets[["TCGA_eset"]])[,"summarystage"])
#same trend for substage
table(pData(esets[["TCGA_eset"]])[,"batch"],pData(esets[["TCGA_eset"]])[,"substage"])

outcomesAndCovariates <- pData(esets[["TCGA_eset"]])[,"batch",drop=FALSE]
rownames(outcomesAndCovariates) <- colnames(exprs(esets[["TCGA_eset"]]))
exprMatrix <- exprs(esets[["TCGA_eset"]])
rownames(exprMatrix) <- featureNames(esets[["TCGA_eset"]])

#p-value after batch correction:
batchCorrect <- batchNormalization(countsMatrixNoNANoDup=exprMatrix,outcomesAndCovariates=outcomesAndCovariates,MinInBatch=4,combatModelFactorName=NULL,pvalueThresh=.05,batchColName="batch",outputFile="combatoutput.txt")
#original p-value:
# batchCorrect$beforePvalue
#[1] 6.129178e-05
#p-value after batch correction:
# batchCorrect$afterPvalue
#[1] 0.5019748
esets[["TCGA_eset"]] <- esets[["TCGA_eset"]][rownames(batchCorrect$GEN_Data_Corrected), colnames(batchCorrect$GEN_Data_Corrected)]
featureNames(esets[["TCGA_eset"]] ) <- rownames(batchCorrect$GEN_Data_Corrected)
validObject(esets[["TCGA_eset"]])


saveRDS(esets,file=paste0(saveDirGlobal,"esets_proc_TCGAcombat.rds"),compress=TRUE)

####
###select features

#now format just as a list of data matrices.
dataMatrixList <- exprSetListToMatrixList(esets,featureDataFieldName="gene")

names(dataMatrixList) <- names(esets)
###save this dataMatrixList now.
saveRDS(dataMatrixList,file=paste0(saveDirGlobal,"curatedOvarianData_procDataMatrixList.rds"))

###meta-features using top 20 by variance for each dataset:
#ran meta-feature analysis for 1000,500,1000,2000 features.
metaFeatures <- selectFeaturesMetaVariance_wrapper(dataMatrixList,rankMethod=c("mad"), 
                                                   numNAstudiesAllowedPerFeat=ceiling(length(dataMatrixList)/10),
                                                   numFeatSelectByGlobalRank=200,
                                                   numTopFeatFromEachDataset=20,fractNATopFeatAllowedPerDataset=.1,selectMethod=c("median"),
                                                   outputFile=outputFile)

message(paste0("Dropping the following datasets: ",paste(names(dataMatrixList)[metaFeatures$datasetListIndicesToRemove],collapse=" ")))

#(saved each one after ran)
saveRDS(metaFeatures,file=paste0(saveDir_20,"/metaFeatures_200.rds"),compress=TRUE)
metaFeatures <- selectFeaturesMetaVariance_wrapper(dataMatrixList,rankMethod=c("mad"), 
                                                   numNAstudiesAllowedPerFeat=ceiling(length(dataMatrixList)/10),
                                                   numFeatSelectByGlobalRank=500,
                                                   numTopFeatFromEachDataset=20,fractNATopFeatAllowedPerDataset=.1,selectMethod=c("median"),
                                                   outputFile=outputFile)

message(paste0("Dropping the following datasets: ",paste(names(dataMatrixList)[metaFeatures$datasetListIndicesToRemove],collapse=" ")))

saveRDS(metaFeatures,file=paste0(saveDir_20,"/metaFeatures_500.rds"),compress=TRUE)

metaFeatures <- selectFeaturesMetaVariance_wrapper(dataMatrixList,rankMethod=c("mad"), 
                                                   numNAstudiesAllowedPerFeat=ceiling(length(dataMatrixList)/10),
                                                   numFeatSelectByGlobalRank=1000,
                                                   numTopFeatFromEachDataset=20,fractNATopFeatAllowedPerDataset=.1,selectMethod=c("median"),
                                                   outputFile=outputFile)

message(paste0("Dropping the following datasets: ",paste(names(dataMatrixList)[metaFeatures$datasetListIndicesToRemove],collapse=" ")))

saveRDS(metaFeatures,file=paste0(saveDir_20,"/metaFeatures_1000.rds"),compress=TRUE)

metaFeatures <- selectFeaturesMetaVariance_wrapper(dataMatrixList,rankMethod=c("mad"), 
                                                   numNAstudiesAllowedPerFeat=ceiling(length(dataMatrixList)/10),
                                                   numFeatSelectByGlobalRank=2000,
                                                   numTopFeatFromEachDataset=20,fractNATopFeatAllowedPerDataset=.1,selectMethod=c("median"),
                                                   outputFile=outputFile)

message(paste0("Dropping the following datasets: ",paste(names(dataMatrixList)[metaFeatures$datasetListIndicesToRemove],collapse=" ")))

saveRDS(metaFeatures,file=paste0(saveDir_20,"/metaFeatures_2000.rds"),compress=TRUE)


###now do without top 20
#ran meta-feature analysis for 1000,500,1000,2000 features.
load(paste0(saveDirGlobal,"/curatedOvarianData_procDataMatrixList.rds"))
metaFeatures <- selectFeaturesMetaVariance_wrapper(dataMatrixList,rankMethod=c("mad"), 
                                                   numNAstudiesAllowedPerFeat=ceiling(length(dataMatrixList)/10),
                                                   numFeatSelectByGlobalRank=200,
                                                   numTopFeatFromEachDataset=0,fractNATopFeatAllowedPerDataset=.1,selectMethod=c("median"),
                                                   outputFile=outputFile)

message(paste0("Dropping the following datasets: ",paste(names(dataMatrixList)[metaFeatures$datasetListIndicesToRemove],collapse=" ")))

#(saved each one after ran)
saveRDS(metaFeatures,file=paste0(saveDir_no20,"/metaFeatures_200.rds"),compress=TRUE)

metaFeatures <- selectFeaturesMetaVariance_wrapper(dataMatrixList,rankMethod=c("mad"), 
                                                   numNAstudiesAllowedPerFeat=ceiling(length(dataMatrixList)/10),
                                                   numFeatSelectByGlobalRank=500,
                                                   numTopFeatFromEachDataset=0,fractNATopFeatAllowedPerDataset=.1,selectMethod=c("median"),
                                                   outputFile=outputFile)

message(paste0("Dropping the following datasets: ",paste(names(dataMatrixList)[metaFeatures$datasetListIndicesToRemove],collapse=" ")))

saveRDS(metaFeatures,file=paste0(saveDir_no20,"/metaFeatures_500.rds"),compress=TRUE)


metaFeatures <- selectFeaturesMetaVariance_wrapper(dataMatrixList,rankMethod=c("mad"), 
                                                   numNAstudiesAllowedPerFeat=ceiling(length(dataMatrixList)/10),
                                                   numFeatSelectByGlobalRank=1000,
                                                   numTopFeatFromEachDataset=0,fractNATopFeatAllowedPerDataset=.1,selectMethod=c("median"),
                                                   outputFile=outputFile)

message(paste0("Dropping the following datasets: ",paste(names(dataMatrixList)[metaFeatures$datasetListIndicesToRemove],collapse=" ")))

saveRDS(metaFeatures,file=paste0(saveDir_no20,"/metaFeatures_1000.rds"),compress=TRUE)


metaFeatures <- selectFeaturesMetaVariance_wrapper(dataMatrixList,rankMethod=c("mad"), 
                                                   numNAstudiesAllowedPerFeat=ceiling(length(dataMatrixList)/10),
                                                   numFeatSelectByGlobalRank=2000,
                                                   numTopFeatFromEachDataset=0,fractNATopFeatAllowedPerDataset=.1,selectMethod=c("median"),
                                                   outputFile=outputFile)

message(paste0("Dropping the following datasets: ",paste(names(dataMatrixList)[metaFeatures$datasetListIndicesToRemove],collapse=" ")))

saveRDS(metaFeatures,file=paste0(saveDir_no20,"/metaFeatures_2000.rds"),compress=TRUE)

##now do 250, 300 - these were for my dissertation to answer the question
#if slightly tweaking the gene set size changed the clusters a lot.

metaFeatures <- selectFeaturesMetaVariance_wrapper(dataMatrixList,rankMethod=c("mad"), 
                                                   numNAstudiesAllowedPerFeat=ceiling(length(dataMatrixList)/10),
                                                   numFeatSelectByGlobalRank=250,
                                                   numTopFeatFromEachDataset=0,fractNATopFeatAllowedPerDataset=.1,selectMethod=c("median"),
                                                   outputFile=outputFile)

message(paste0("Dropping the following datasets: ",paste(names(dataMatrixList)[metaFeatures$datasetListIndicesToRemove],collapse=" ")))

saveRDS(metaFeatures,file=paste0(saveDir_no20,"/metaFeatures_250.rds"),compress=TRUE)


metaFeatures <- selectFeaturesMetaVariance_wrapper(dataMatrixList,rankMethod=c("mad"), 
                                                   numNAstudiesAllowedPerFeat=ceiling(length(dataMatrixList)/10),
                                                   numFeatSelectByGlobalRank=300,
                                                   numTopFeatFromEachDataset=0,fractNATopFeatAllowedPerDataset=.1,selectMethod=c("median"),
                                                   outputFile=outputFile)

message(paste0("Dropping the following datasets: ",paste(names(dataMatrixList)[metaFeatures$datasetListIndicesToRemove],collapse=" ")))

saveRDS(metaFeatures,file=pase0(saveDir_no20,"/metaFeatures_300.rds"),compress=TRUE)




