library(dplyr)
library(ggplot2)

#IOP (Informative observation process)
IOP_BX <- TRUE #Informative observation process for biopsy
IOP_SURG <- TRUE #Informative observation process for surgery
leave_one_out <- FALSE
crop<-FALSE

IOPs<-paste0(
	c('N')[!IOP_BX],'IOP_BX-',
	c('N')[!IOP_SURG],'IOP_SURG')
batch_path<-paste0(
	'batches/',
	IOPs,
	'/leave_one_out_',leave_one_out,
	'/crop_',crop,
	'/batch-1/')
posterior_path<-paste0(batch_path,
	'concatenated_posterior.rds')




###############
# Load Data


psa_data_full<-read.csv("simulation-data/psa-data-sim.csv")
pt_data_full<-read.csv("simulation-data/pt-data-sim.csv") #true eta is now contained here, in patient data (pt data)
bx_data_full <- read.csv("simulation-data/bx-data-sim.csv")




of <- readRDS(posterior_path) # Output from full model
missing_etas <- which(is.na(pt_data_full$obs_eta)) #obs_eta=1 if observed and aggressive, 0 if observed and not aggressive, or NA if not observed
eta_true_or_jags<-pt_data_full$obs_eta
eta_true_or_jags[missing_etas]<-colMeans(of$eta_hat_means) #indexed by subject

nsim <- dim(of1<-of$eta_hat_means)[1]
eta_jags1<-colMeans(of$eta_hat_means[1:nsim <  nsim/2,])
eta_jags2<-colMeans(of$eta_hat_means[1:nsim >= nsim/2,])
quantile(abs(eta_jags1-eta_jags2),prob=c(.5,.9,.99,1))
	# Note - from "two" MCMC samples the concordance is very high. About 10 times higher than what we get with IS.
#############


#############
# Combine results from parallel jobs

load(paste0(batch_path,'/2015-10-16_seed_101_IOP_BX-TRUE_IOP_SURG-TRUE_P-5e+06_online_fit_results.RData')) #small & dynamic matrices


files <- dir(batch_path)
fitfiles <- files[grep('online',files)]

bigAll <- data.frame()
bigfiles <- files[grep('big',files)]
for(i in 1:length(bigfiles)){

	big_i <- readRDS(paste(batch_path,bigfiles[i],sep='/'))
	bigAll <- rbind(bigAll,big_i)

}
bigAll <- bigAll[order(bigAll$subj),]
as.tbl(bigAll)


	

small$draw_type<-'small'
dynamic$draw_type<-'dynamic'
bigAll$draw_type<-'big'



ofits<-rbind(small,dynamic,bigAll) #out of sample fits

ofits$etas_jags<- eta_true_or_jags[ofits$subj]
ofits<-mutate(ofits, squared_errors_IS = (etas_jags-etas_IS)^2)
ofits<-mutate(ofits, errors_ZW_abs = sqrt((etas_jags-etas_ZW)^2) )

ofits<-mutate(ofits, errors_IS_abs = sqrt((etas_jags-etas_IS)^2) )
ofits<-mutate(ofits, errors_ZW_abs = sqrt((etas_jags-etas_ZW)^2) )

# saveRDS(ofits,file=paste0(batch_path,'/ISfitsConcatenated.rds'))
# ofits<-readRDS(paste0(batch_path,'/ISfitsConcatenated.rds'))
#############




#############
#Explore results

timeq<-c(0,.05,.25,.75,.9,.95,1)
print(data.frame(
	small=quantile(filter(ofits, draw_type=='small')$time_IS,
		probs=timeq),
	big=quantile(filter(ofits, draw_type=='big')$time_IS,
		probs=timeq)/60,
	dynamicSec=quantile(filter(ofits, draw_type=='dynamic')$time_IS,
		probs=timeq),
	dynamicMin=quantile(filter(ofits, draw_type=='dynamic')$time_IS,
		probs=timeq)/60
))


#root mean squared error for IS & RS
filter(ofits, draw_type=='dynamic')%>% 
	transmute(sq_err=(etas_jags-etas_IS)^2) %>%
	summarize(mean(sq_err)) %>%
	sqrt
filter(ofits, draw_type=='dynamic')%>%
	transmute(sq_err=(etas_jags-etas_RS)^2) %>%
	summarize(mean(sq_err)) %>%
	sqrt


#Distribution of errors
errorq<-c(.5,.8,.9,.95,.99,1)
print(data.frame(
	'dynamic'=quantile(filter(ofits, draw_type=='dynamic')$errors_IS_abs,
		probs=errorq),
	'small'=quantile(filter(ofits, draw_type=='small')$errors_IS_abs,
		probs=errorq),
	'big'=quantile(filter(ofits, draw_type=='big')$errors_IS_abs,
		probs=errorq)
))


#How many particles ended up being drawn?
range(filter(ofits, draw_type=='big')$particle_draws)
range(filter(ofits, draw_type=='small')$particle_draws)
range(filter(ofits, draw_type=='dynamic')$particle_draws)



png(paste0('plots/',Sys.Date(),'_ESS_error_log.png'),height=450,width=510,pointsize=19,type='cairo')
ggplot(ofits) + geom_point(aes(x=effective_ss, y=errors_IS_abs,color=draw_type),cex=1.1) +
	scale_y_log10(breaks=c(.1,.05,.01,.005,.001)) +
	scale_x_log10(breaks=c(10^c(1:7)))+
	theme(text=element_text(size=18)) +
	labs(title='Effective Sample Size v. Absolute Error',x='Effective sample size for IS (log spacing)',y='Absolute difference (log spacing)', color='Candidate\ngenerating\nscheme') +
	geom_vline(xintercept=1000,lty=2)+
	theme(axis.text.x=element_text(angle=35, hjust = 1))
dev.off()

png(paste0('plots/',Sys.Date(),'_agreement_IS_MCMC.png'),height=450,width=505,pointsize=19,type='cairo')
ggplot(ofits)+geom_point(aes(x=etas_IS,y=etas_jags,color=draw_type),cex=1.2) +
	theme(text=element_text(size=18)) +
	labs(title='Agreement of risk estimates from\nIS and MCMC',x='Risk estimates from IS',y='Risk estimates from MCMC', color='Candidate\ngenerating\nscheme')
dev.off()



