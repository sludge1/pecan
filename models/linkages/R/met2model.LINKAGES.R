#-------------------------------------------------------------------------------
# Copyright (c) 2012 University of Illinois, NCSA.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the 
# University of Illinois/NCSA Open Source License
# which accompanies this distribution, and is available at
# http://opensource.ncsa.illinois.edu/license.html
#-------------------------------------------------------------------------------

##-------------------------------------------------------------------------------------------------#
##' Converts a met CF file to a model specific met file. The input
##' files are calld <in.path>/<in.prefix>.YYYY.cf
##'
##' @name met2model.LINKAGES
##' @title Write LINKAGES met files
##' @param in.path path on disk where CF file lives
##' @param in.prefix prefix for each file
##' @param outfolder location where model specific output is written.
##' @return OK if everything was succesful.
##' @export
##' @author Ann Raiho, Betsy Cowdery
##-------------------------------------------------------------------------------------------------#
met2model.LINKAGES <- function(in.path, in.prefix, outfolder, start_date, end_date, ..., overwrite=FALSE,verbose=FALSE) {
  require(PEcAn.utils)
   
  start_date <- as.POSIXlt(start_date, tz = "GMT")
  end_date<- as.POSIXlt(end_date, tz = "GMT")
  out.file <- file.path(paste0(outfolder,"test_text1.txt"))
#   out.file <- file.path(outfolder, paste(in.prefix,
#                                          strptime(start_date, "%Y-%m-%d"),
#                                          strptime(end_date, "%Y-%m-%d"),
#                                          "dat", sep="."))
  
  results <- data.frame(file=c(out.file),
                        host=c(fqdn()),
                        mimetype=c('text/plain'),
                        formatname=c('DALEC meteorology'),
                        startdate=c(start_date),
                        enddate=c(end_date),
                        dbfile.name = "test_text1.txt",
                        stringsAsFactors = FALSE)
  print("internal results")
  print(results)
  
  if (file.exists(out.file) && !overwrite) {
    logger.debug("File '", out.file, "' already exists, skipping to next file.")
    return(invisible(results))
  }
  
  require(ncdf4)
  require(lubridate)
  require(PEcAn.data.atmosphere)
  #  require(ncdf)
  
  ## check to see if the outfolder is defined, if not create directory for output
  if(!file.exists(outfolder)){
    dir.create(outfolder)
  }
  
  out <- NULL
  
  # get start/end year since inputs are specified on year basis
  start_year <- year(start_date)
  end_year <- year(end_date)
  
  year = seq(start_year,end_year,1)
  
  month_matrix_precip = matrix(NA,length(year),12)
  julian_vec_hr = c(1,c(32,60,91,121,152,182,213,244,274,305,335,365)*4)
  
  for(i in 1:length(year)){
    ncin <- nc_open(file.path(in.path,paste0(in.prefix,".",year[i],".nc")))
    #print(ncin)
    ncprecipf = ncvar_get(ncin, "precipitation_flux") #units are kg m-2 s-1    
    for(m in 1:12){
      month_matrix_precip[i,m] = sum(ncprecipf[julian_vec_hr[m]:(julian_vec_hr[m+1]-1)]) * 21600^2 #fix when Mike changes code
    } 
    nc_close(ncin)
    #if(i%%100==0) cat(i," "); flush.console()
  }
  
  nyear = length(year) #number of years to simulate
  ipolat_nums = seq(2,nyear,25) #years for climate interpolation
  mean_ncprecipf_mm = matrix(0,length(ipolat_nums),12) ; mean_ncprecipf_cm = mean_ncprecipf_mm; sd_ncprecipf_mm = mean_ncprecipf_mm ;sd_ncprecipf_cm = mean_ncprecipf_mm
  
  for(i in 1:length(ipolat_nums)){
    for(m in 1:12){
      mean_ncprecipf_mm[i,m] = mean(month_matrix_precip[ipolat_nums[i],m],month_matrix_precip[ipolat_nums[i]-1,m])
      sd_ncprecipf_mm[i,m] = sd(c(month_matrix_precip[ipolat_nums[i],m],month_matrix_precip[ipolat_nums[i]-1,m]))
    }  
  }
  
  mean_ncprecipf_cm <- round(mean_ncprecipf_mm / 10,digits = 1)
  sd_ncprecipf_cm <- round(sd_ncprecipf_mm / 10,digits = 1)
  
  month_matrix_temp_mean = matrix(NA,length(year),12)
  
  for(i in 1:length(year)){
    ncin <- nc_open(file.path(in.path,paste0(in.prefix,".",year[i],".nc")))
    #print(ncin)
    nctemp = ncvar_get(ncin, "air_temperature") #units are kg m-2 s-1    
    for(m in 1:12){
      month_matrix_temp_mean[i,m] = mean(nctemp[julian_vec_hr[m]:(julian_vec_hr[m+1]-1)]) #sub daily to monthly
    } 
    nc_close(ncin)
    #if(i%%100==0) cat(i," "); flush.console()
  }
  
  mean_nctemp = matrix(0,length(ipolat_nums),12) ; sd_nctemp = mean_nctemp
  for(i in 1:length(ipolat_nums)){
    for(m in 1:12){
      mean_nctemp[i,m] = mean(month_matrix_temp_mean[ipolat_nums[i],m],month_matrix_temp_mean[ipolat_nums[i]-1,m])
      sd_nctemp[i,m] = sd(c(month_matrix_temp_mean[ipolat_nums[i],m],month_matrix_temp_mean[ipolat_nums[i]-1,m]))
    }  
  }
  
  mean_nctemp_C <- round(mean_nctemp - 273.15, digits = 1)
  sd_nctemp_C <- round(sd_nctemp, digits = 1)
  
  write.table(rbind(mean_nctemp_C,sd_nctemp_C,mean_ncprecipf_cm,sd_ncprecipf_cm),out.file,quote = FALSE,sep=",",col.names=FALSE,row.names=FALSE)
  invisible(results)
}
