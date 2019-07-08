#Kevin Kowalski kjk226 6/17/2019

import matplotlib as mp
import matplotlib.pyplot as plt
from matplotlib.ticker import MultipleLocator
from tao_interface import *
from parameters import *
import time
import matplotlib.patches as patches
import numpy as np

#pipe=tao_interface('pexpect','-init_file ../examples/cesr/tao.init')
#determines tao settings and lattice to be used eg: '-init_file ../examples/cesr/tao.init' for CESR

#GraphRegion='top'
#region in tao of plot

class taoplot:
	def __init__(self,pipe,GraphRegion):
		self.pipe= pipe
		#tao_interface object
		self.GraphRegion= GraphRegion
		#string describing region in tao of the desired plot

	def plot(self):
		'''plots a graph using the data in the region GraphRegion of the tao instance in pipe, and plots a lat_layout below if applicable'''
		fig = plt.figure()
		#creates plotting figure
		pipe = self.pipe
		GraphRegion = self.GraphRegion
		LatLayout=False
		FloorPlan=False

		def pgp_to_mpl(x):
			'''takes string with pgplot characters and returns string with characters replaced with matplotlib equivalent, raises NotImplementedError if an unknown pgplot character is used'''
			x=x.replace('\\','\\\\')
			if '\\\\' in x:
				lx = '$'+x+'$'
				while lx.find('\\\\d') != -1 and lx.find('\\\\u') != -1:
					if lx.find('\\\\d') <	lx.find('\\\\u'):
						if lx.find('\\\\d') != -1:
							start=lx.find('\\\\d')
							end=lx.find('\\\\u')
							sx=lx[start:end+3]
							lx=lx.replace(sx,'_'+sx[3:-3])
							sx=''
							start=''
					else:
						if lx.find('\\\\u') != -1:
							start=lx.find('\\\\u')
							end=lx.find('\\\\d')
							sx=lx[start:end+3]
							lx=lx.replace(sx,'^'+sx[3:-3])
							sx=''
							start=''
							end=''

				lx=lx.replace(' ','\\ ')

				lx=lx.replace('\\\\(2265)','\\partial')
				lx=lx.replace('\\\\ga','\\alpha')
				lx=lx.replace('\\\\gb','\\beta')
				lx=lx.replace('\\\\gg','\\gamma')
				lx=lx.replace('\\\\gd','\\delta')
				lx=lx.replace('\\\\ge','\\epsilon')
				lx=lx.replace('\\\\gz','\\zeta')
				lx=lx.replace('\\\\gy','\\eta')
				lx=lx.replace('\\\\gh','\\theta')
				lx=lx.replace('\\\\gi','\\iota')
				lx=lx.replace('\\\\gk','\\kappa')
				lx=lx.replace('\\\\gl','\\lambda')
				lx=lx.replace('\\\\gm','\\mu')
				lx=lx.replace('\\\\gn','\\nu')
				lx=lx.replace('\\\\gc','\\xi')
				lx=lx.replace('\\\\go','\\omicron')
				lx=lx.replace('\\\\gp','\\pi')
				lx=lx.replace('\\\\gr','\\rho')
				lx=lx.replace('\\\\gs','\\sigma')
				lx=lx.replace('\\\\gt','\\tau')
				lx=lx.replace('\\\\gu','\\upsilon')
				lx=lx.replace('\\\\gf','\\phi')
				lx=lx.replace('\\\\gx','\\chi')
				lx=lx.replace('\\\\gq','\\psi')
				lx=lx.replace('\\\\gw','\\omega')

				lx=lx.replace('\\\\gA','A')
				lx=lx.replace('\\\\gB','B')
				lx=lx.replace('\\\\gG','\\Gamma')
				lx=lx.replace('\\\\gD','\\Delta')
				lx=lx.replace('\\\\gE','E')
				lx=lx.replace('\\\\gZ','Z')
				lx=lx.replace('\\\\gY','H')
				lx=lx.replace('\\\\gH','\\Theta')
				lx=lx.replace('\\\\gI','I')
				lx=lx.replace('\\\\gK','\\Kappa')
				lx=lx.replace('\\\\gL','\\Lambda')
				lx=lx.replace('\\\\gM','M')
				lx=lx.replace('\\\\gN','N')
				lx=lx.replace('\\\\gC','\\Xi')
				lx=lx.replace('\\\\gO','O')
				lx=lx.replace('\\\\gP','\\Pi')
				lx=lx.replace('\\\\gR','P')
				lx=lx.replace('\\\\gS','\\Sigma')
				lx=lx.replace('\\\\gT','T')
				lx=lx.replace('\\\\gU','\\Upsilon')
				lx=lx.replace('\\\\gF','\\Phi')
				lx=lx.replace('\\\\gX','X')
				lx=lx.replace('\\\\gQ','\\Psi')
				lx=lx.replace('\\\\gW','\\Omega')
				if '\\\\' in lx:
					raise NotImplementedError('unknown character in string, character not yet added to pgp_to_mpl')
				return lx
			else:
				return x

		SymbolsDict={
			'square':'s', #no fill
			'dot':'.',
			'plus':'+',
			'times':(6,2,0),
			'circle':'$\\circ$', 
			'x':'x',
			'triangle':'^', #no fill
			'circle_plus':'$\\oplus$',
			'circle_dot':'$\\odot$',
			'square_concave':(4,1,45),
			'diamond':'d', #no fill
			'star5':'*', #no fill
			'triangle_filled':'^', #fill
			'red_cross':'P',
			'star_of_david':(6,1,0),
			'square_filled':'s', #fill
			'circle_filled':'o', #fill
			'star5_filled':'*', #fill
			'0':'s', #no fill
			'1':'.',
			'2':'+',
			'3':(6,2,0),
			'4':'$\\circ$', 
			'5':'x',
			'6':'s',
			'7':'^', #no fill
			'8':'$\\oplus$',
			'9':'$\\odot$',
			'10':(4,1,45),
			'11':'d', #no fill
			'12':'*', #no fill
			'13':'^', #fill
			'14':'P',
			'15':(6,1,0),
			'16':'s', #fill
			'17':'o', #fill
			'18':'*', #fill
			'-1':',',
			'-2':',',
			'-3':'(3,0,0)',
			'-4':'(4,0,0)',
			'-5':'(5,0,0)',
			'-6':'(6,0,0)',
			'-7':'(7,0,0)',
			'-8':'(8,0,0)',
			'-9':'(9,0,0)',
			'-10':'(10,0,0)',
			'-11':'(11,0,0)',
			'-12':'(12,0,0)'
		}
		#Dictionary with pgplot symbol strings as keys and corresponding matplotlib symbol strings as values




		'''''''''Graphing'''''''''

		'''Region Data'''

		rInfo=pipe.cmd_in('python plot1 '+GraphRegion).splitlines()
		#list of plotting parameter strings from tao command python plot1

		rInfoList = []
		rInfoDict = {}
		for i in range(len(rInfo)):
			rInfoDict[rInfo[i].split(';')[0]]=str_to_tao_param(rInfo[i])
			rInfoList.append(rInfo[i].split(';')[0])
		#list of tao_parameter object names from python plot_1
		#dictionary of tao_parameter name string keys to the corresponding tao_parameter object

		gList = []
		for i in range(rInfoDict['num_graphs'].value):
			gList.append(rInfoDict[('graph['+str(i+1)+']')].value)
		#list of string names of graphs

		GraphDict = {}
			

		for gNumber in range(len(gList)):

			if gNumber == 0:
				GraphDict['graph'+str(gNumber+1)]=fig.add_subplot(len(gList)+1,1,gNumber+1)
			elif gNumber > 0:
				GraphDict['graph'+str(gNumber+1)]=fig.add_subplot(len(gList)+1,1,gNumber+1,sharex=GraphDict['graph1'])
			#create plots in figure, second line also makes x axes scale together



			'''Graph Data'''

			gType = GraphRegion+'.'+gList[gNumber]
			#graph type, like r13.g or top.x


			gInfo=pipe.cmd_in('python plot_graph '+gType).splitlines()
			#list of plotting parameter strings from tao command python plot_graph


			gInfoList = []
			gInfoDict = {}
			for i in range(len(gInfo)):
				gInfoDict[gInfo[i].split(';')[0]]=str_to_tao_param(gInfo[i])
				gInfoList.append(gInfo[i].split(';')[0])
			#list of tao_parameter object names from python plot_graph
			#dictionary of tao_parameter name string keys to the corresponding tao_parameter object




			'''Curve Data'''

			cList=[]
			for i in range(gInfoDict['num_curves'].value):
				cList.append(gInfoDict[('curve['+str(i+1)+']')].value)
			#list of string names of curves

			cInfo=[]
			for i in cList:
				cInfo.append(pipe.cmd_in('python plot_curve '+gType+'.'+i).splitlines())
			#list of lists of plotting parameter strings from tao command python plot_curve for each curve

			cInfoSuperList=[]
			cInfoDictList=[]
			for i in range(len(cList)):
				cInfoList = []
				cInfoDict = {}
				for j in range(len(cInfo[i])):
					cInfoDict[cInfo[i][j].split(';')[0]]=str_to_tao_param(cInfo[i][j])
					cInfoList.append(cInfo[i][j].split(';')[0])
				cInfoSuperList.append(cInfoList)
				cInfoDictList.append(cInfoDict)
				cInfoList = []
				cInfoDict = {}
			#list of lists of tao_parameter object names from python plot_graph for each curve
			#list of dictionaries of tao_parameter name string keys to the corresponding tao_parameter object for each curve

			#print(cInfoDictList[1]['name'].value) #gives name of 2nd curve which is y for orbit




			'''Line Data'''

			lInfo=[]
			try:
				for i in cList:
					lInfo.append(pipe.cmd_in('python plot_line '+gType+'.'+i).splitlines())
				#list of points from tao command python plot_line for each curve
				if len(lInfo) != 0:
					PointsSuperList=[]
					for i in range(len(cList)):
						pList = []
						for j in range(len(lInfo[i])):
							pList.append(lInfo[i][j].split(';'))
						LineCoords = []
						for j in range(len(pList)):
							LineCoords.append([float(pList[j][1]),float(pList[j][2])])
						PointsSuperList.append(LineCoords)
						LineCoords=[]
					#list of lists of points used to draw each curve
			except:
				lInfo=[]
				PointsSuperList = []
				for i in cList:
					PointsSuperList.append([[0,0]])


			'''Symbol Data'''

			try:
				sInfo=[]
				for i in cList:
					sInfo.append(pipe.cmd_in('python plot_symbol '+gType+'.'+i).splitlines())
				#list of points from tao command python plot_symbol for each curve

				SymbolSuperList=[]
				for i in range(len(cList)):
					sList = []
					for j in range(len(sInfo[i])):
						sList.append(sInfo[i][j].split(';'))
					SymCoords = []
					for j in range(len(sList)):
						SymCoords.append([float(sList[j][2]),float(sList[j][3])])
					SymbolSuperList.append(SymCoords)
					SymCoords=[]
				#list of lists of points used to draw symbols on each curve
			except:
				sInfo = []
				SymbolSuperList = []
				for i in cList:
					SymbolSuperList.append([[0,0]])




			'''Histogram Data'''

			try:
				hInfo=[]
				for i in cList:
					hInfo.append(pipe.cmd_in('python plot_histogram '+gType+'.'+i).splitlines())
				hInfoDictList=[]
				for i in range(len(cList)):
					hInfoDict = {}
					for j in range(len(hInfo[i])):
						hInfoDict[hInfo[i][j].split(';')[0]]=str_to_tao_param(hInfo[i][j])
					hInfoDictList.append(hInfoDict)
					hInfoDict = {}
				#list of lists of dictionaries of plot_histogram data for each curve
			except:
				hInfo=[]




			'''Plot Data'''

			CurvesList = []
			for i in range(len(cList)):
				CurveData = []
				CurveData.append(PointsSuperList[i])
				CurveData.append(SymbolSuperList[i])
				CurveData.append(cInfoDictList[i]['line.color'].value)
				CurveData.append(cInfoDictList[i]['line.pattern'].value.lower())
				CurveData.append(cInfoDictList[i]['line.width'].value)
				CurveData.append(cInfoDictList[i]['symbol.color'].value)
				if (cInfoDictList[i]['symbol.fill_pattern'] == 'solid_fill'):
					CurveData.append(cInfoDictList[i]['symbol.color'].value)
				else:
					CurveData.append('none')
				if (cInfoDictList[i]['draw_symbols'].value == True):
					CurveData.append(cInfoDictList[i]['symbol.height'].value)
				else:
					CurveData.append(0)
				CurveData.append(SymbolsDict[cInfoDictList[i]['symbol.type'].value])
				#if fill and sizing are not automatic for certain symbols, override here 
				CurveData.append(cInfoDictList[i]['symbol.line_width'].value)
				CurvesList.append(CurveData)
				CurveData = []
			#list of [PointsList,SymbolsList,line color,linetype,linewidth,marker color,marker fill type,markertype,markersize] for each curve
			#example: [[[(4,2),(2,5),(0,1),(3,5),(1,2)],[(4,2),(2,5),(0,1)],'Blue','dashed',2,'Blue','s',5],[[(4,3),(2,4),(0,7),(1,6),(3,3)],[(4,3),(2,4),(0,7)],'Orange','solid',2,'Orange','o',5]]




			'''Plotting'''

			#x=[[(4,2),(2,5),(0,1),(3,5),(1,2)],[(4,2),(2,5),(0,1)],'tab:blue','dashed',2,'tab:blue','s',5]
			#y=[[(4,3),(2,4),(0,7),(1,6),(3,3)],[(4,3),(2,4),(0,7)],'tab:orange','solid',2,'tab:orange','o',5]

			#infofromtao [CurvesList,title,xlabel,ylabel,grid]

			LineList = []
			for i in CurvesList:
				PointsList = i[0]
				SymbolsList = i[1]
				PointsList.sort()
				SymbolsList.sort()
				xpList = []
				ypList = []
				for j in PointsList:
					xpList.append(j[0])
					ypList.append(j[1])
				xsList = []
				ysList = []
				for k in SymbolsList:
					xsList.append(k[0])
					ysList.append(k[1])

				if gInfoDict['graph^type'].value == 'data':
					LineList.append(GraphDict['graph'+str(gNumber+1)].plot(xpList,ypList,color=i[2],linestyle=i[3],linewidth=i[4]/2))
					GraphDict['graph'+str(gNumber+1)].plot(xsList,ysList,color=i[5],linewidth=0,markerfacecolor=i[6],markersize=i[7]/2,marker=i[8],mew=i[9]/2)
					LatLayout = True
				#line and symbol graphs

				elif gInfoDict['graph^type'].value == 'phase_space':	
					if lInfo != []:
						LineList.append(GraphDict['graph'+str(gNumber+1)].plot(xpList,ypList,color=i[2],linestyle=i[3],linewidth=i[4]/2))
						GraphDict['graph'+str(gNumber+1)].plot(xsList,ysList,color=i[5],linewidth=0,markerfacecolor=i[6],markersize=i[7]/2,marker=i[8],mew=i[9]/2)
					else:
						LineList.append(GraphDict['graph'+str(gNumber+1)].plot(xsList,ysList,color=i[5],linewidth=0,markerfacecolor=i[6],markersize=i[7]/2,marker=i[8],mew=i[9]/2))
				#phase space graphs

				elif gInfoDict['graph^type'].value == 'histogram':
					LineList.append(GraphDict['graph'+str(gNumber+1)].hist(xpList,bins=int(hInfoDictList[CurvesList.index(i)]['number'].value),weights=ypList,histtype='step',color=i[5]))
				#histogram	

			if gInfoDict['graph^type'].value == 'lat_layout':
				LatLayout = True
				gList = []
				plt.axis('off')
			#sets up lat layout plot

			if gInfoDict['graph^type'].value == 'floor_plan':
				FloorPlan = True
				gList = []
				plt.axis('off')
			#sets up floor plan plot		

			#plot curves
			#LineList gives names of curves

			


			plt.title(pgp_to_mpl(gInfoDict['title'].value)+' '+gInfoDict['title_suffix'].value)
			#plot title

			LegendList = []
			LabelList = []
			for i in range(len(CurvesList)):
				LegendList.append(LineList[i][0])
				LabelList.append(pgp_to_mpl(cInfoDictList[i]['legend_text'].value))

			if (gInfoDict['draw_curve_legend'].value == True and LabelList != ['']) and gInfoDict['graph^type'].value != 'lat_layout' and gInfoDict['graph^type'].value != 'floor_plan':
				GraphDict['graph'+str(gNumber+1)].legend(LegendList,LabelList)
			#plot legend

			plt.xlabel(pgp_to_mpl(gInfoDict['x.label'].value))
			plt.ylabel(pgp_to_mpl(gInfoDict['y.label'].value))
			#plot axis labels

			xmajorLocator=MultipleLocator((gInfoDict['x.max'].value-gInfoDict['x.min'].value)/gInfoDict['x.major_div'].value)
			ymajorLocator=MultipleLocator((gInfoDict['y.max'].value-gInfoDict['y.min'].value)/gInfoDict['y.major_div'].value)
			GraphDict['graph'+str(gNumber+1)].xaxis.set_major_locator(xmajorLocator)
			GraphDict['graph'+str(gNumber+1)].yaxis.set_major_locator(ymajorLocator)
			GraphDict['graph'+str(gNumber+1)].grid(gInfoDict['draw_grid'].value,which='major',axis='both')
			plt.xlim(gInfoDict['x.min'].value,gInfoDict['x.max'].value)
			plt.ylim(gInfoDict['y.min'].value,gInfoDict['y.max'].value)
			GraphDict['graph'+str(gNumber+1)].set_axisbelow(True)
			#plot grid
			
		



		'''Lattice Layout'''
		
		if LatLayout == True:
			GraphDict['LatLayout']=fig.add_subplot(len(gList)+1,1,len(gList)+1,sharex=GraphDict['graph1'])

			



			layInfo=pipe.cmd_in('python plot_graph r1.g').splitlines()
			#list of plotting parameter strings from tao command python plot_graph


			layInfoList = []
			layInfoDict = {}
			for i in range(len(layInfo)):
				layInfoDict[layInfo[i].split(';')[0]]=str_to_tao_param(layInfo[i])
				layInfoList.append(layInfo[i].split(';')[0])
			#list of tao_parameter object names from python plot_graph
			#dictionary of tao_parameter name string keys to the corresponding tao_parameter object


			
			twinAxes=GraphDict['LatLayout'].axes.twinx()
			plt.xlim(gInfoDict['x.min'].value,gInfoDict['x.max'].value)
			plt.ylim(layInfoDict['y.min'].value,layInfoDict['y.max'].value)
			twinAxes.set_navigate(True)

			GraphDict['LatLayout'].axis('off')
			twinAxes.axis('off')
			
			GraphDict['LatLayout'].axes.set_navigate(False)
			GraphDict['LatLayout'].axhline(y=0,xmin=1.1*layInfoDict['x.min'].value,xmax=1.1*layInfoDict['x.max'].value,color='Black')
			#sets axis limits and creates second axis to allow x panning and zooming
			

			if layInfoDict['ix_universe'].value != -1:
				universe = layInfoDict[ix_universe].value
			
			else:
				universe = 1

			branch = layInfoDict['-1^ix_branch'].value


			shapes=pipe.cmd_in('python plot_shapes lat_layout').splitlines()
			shapeTypeDict = {}
			shapeColorDict = {}
			shapeHeightDict = {}
			shapeNameDict = {}
			for i in range(len(shapes)):
				shapeTypeDict[shapes[i].split(';')[1][:-3].lower()]= shapes[i].split(';')[2].lower()
				shapeColorDict[shapes[i].split(';')[1][:-3].lower()]= shapes[i].split(';')[3].lower()
				shapeHeightDict[shapes[i].split(';')[1][:-3].lower()]= float(shapes[i].split(';')[4])
				shapeNameDict[shapes[i].split(';')[1][:-3].lower()]= shapes[i].split(';')[6]
			#dictionaries of element type strings as keys with corresponding information as values 


			
			eleInfo=pipe.cmd_in('python plot_lat_layout '+str(universe)+'@'+str(branch)).splitlines()
			#list of strings containing information about each element

			eleIndexList = []
			eleStartDict = {}
			eleEndDict = {}
			eleLwDict = {}
			eleShapeDict = {}
			eleY1Dict = {} #height above 0 
			eleY2Dict = {} #height below 0
			eleColorDict = {}
			eleNameDict = {}
			for i in range(len(eleInfo)):
				eleIndexList.append(int(eleInfo[i].split(';')[0]))
				eleStartDict[eleInfo[i].split(';')[0]]= float(eleInfo[i].split(';')[1])
				eleEndDict[eleInfo[i].split(';')[0]]= float(eleInfo[i].split(';')[2])
				eleLwDict[eleInfo[i].split(';')[0]]= float(eleInfo[i].split(';')[3])
				eleShapeDict[eleInfo[i].split(';')[0]]= eleInfo[i].split(';')[4].lower()
				eleY1Dict[eleInfo[i].split(';')[0]]= float(eleInfo[i].split(';')[5])
				eleY2Dict[eleInfo[i].split(';')[0]]= float(eleInfo[i].split(';')[6])
				eleColorDict[eleInfo[i].split(';')[0]]= eleInfo[i].split(';')[7].lower()
				eleNameDict[eleInfo[i].split(';')[0]]= eleInfo[i].split(';')[8]
			#all dict keys and entries are strings which match a lattice layout element index (eg: '1') string to the corresponding information


			for i in eleIndexList:
				try:
					if eleShapeDict[str(i)] == 'box' and eleEndDict[str(i)]-eleStartDict[str(i)] > 0:		
						GraphDict['LatLayout'].add_patch(patches.Rectangle((eleStartDict[str(i)],-1*eleY2Dict[str(i)]),eleEndDict[str(i)]-eleStartDict[str(i)],eleY1Dict[str(i)]+eleY2Dict[str(i)],lw=eleLwDict[str(i)],color=eleColorDict[str(i)],fill=False))
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],eleEndDict[str(i)]],[eleY1Dict[str(i)],-1*eleY2Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)],alpha=0)
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],eleEndDict[str(i)]],[-1*eleY2Dict[str(i)],eleY1Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)],alpha=0)
					#draw box element	




					elif eleShapeDict[str(i)] == 'xbox' and eleEndDict[str(i)]-eleStartDict[str(i)] > 0:
						GraphDict['LatLayout'].add_patch(patches.Rectangle((eleStartDict[str(i)],-1*eleY2Dict[str(i)]),eleEndDict[str(i)]-eleStartDict[str(i)],eleY1Dict[str(i)]+eleY2Dict[str(i)],lw=eleLwDict[str(i)],color=eleColorDict[str(i)],fill=False))
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],eleEndDict[str(i)]],[eleY1Dict[str(i)],-1*eleY2Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],eleEndDict[str(i)]],[-1*eleY2Dict[str(i)],eleY1Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])			
					#draw xbox element




					elif eleShapeDict[str(i)] == 'x' and eleEndDict[str(i)]-eleStartDict[str(i)] > 0:
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],eleEndDict[str(i)]],[eleY1Dict[str(i)],-1*eleY2Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],eleEndDict[str(i)]],[-1*eleY2Dict[str(i)],eleY1Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
					#draw x element
				


					elif eleShapeDict[str(i)] == 'bow_tie' and eleEndDict[str(i)]-eleStartDict[str(i)] > 0:
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],eleEndDict[str(i)]],[eleY1Dict[str(i)],-1*eleY2Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],eleEndDict[str(i)]],[-1*eleY2Dict[str(i)],eleY1Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])	
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],eleEndDict[str(i)]],[eleY1Dict[str(i)],eleY1Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],eleEndDict[str(i)]],[-1*eleY2Dict[str(i)],-1*eleY2Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
					#draw bow_tie element	
					


					elif eleShapeDict[str(i)] == 'diamond' and eleEndDict[str(i)]-eleStartDict[str(i)] > 0:
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],eleStartDict[str(i)]+(eleEndDict[str(i)]-eleStartDict[str(i)])/2],[0,-1*eleY2Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],eleStartDict[str(i)]+(eleEndDict[str(i)]-eleStartDict[str(i)])/2],[0,eleY1Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([eleStartDict[str(i)]+(eleEndDict[str(i)]-eleStartDict[str(i)])/2,eleEndDict[str(i)]],[-1*eleY2Dict[str(i)],0],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([eleStartDict[str(i)]+(eleEndDict[str(i)]-eleStartDict[str(i)])/2,eleEndDict[str(i)]],[eleY1Dict[str(i)],0],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
					#draw diamond element	



					elif eleShapeDict[str(i)] == 'circle':
						GraphDict['LatLayout'].add_patch(patches.Ellipse((eleStartDict[str(i)]+(eleEndDict[str(i)]-eleStartDict[str(i)])/2,0),(eleEndDict[str(i)]-eleStartDict[str(i)]),eleY1Dict[str(i)]+eleY2Dict[str(i)],lw=eleLwDict[str(i)],color=eleColorDict[str(i)],fill=False))
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],eleEndDict[str(i)]],[eleY1Dict[str(i)],-1*eleY2Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)],alpha=0)
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],eleEndDict[str(i)]],[-1*eleY2Dict[str(i)],eleY1Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)],alpha=0)
					#draw circle element



					elif eleShapeDict[str(i)] == 'box' and eleEndDict[str(i)]-eleStartDict[str(i)] < 0:	
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],layInfoDict['x.max'].value],[eleY1Dict[str(i)],eleY1Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([layInfoDict['x.min'].value,eleEndDict[str(i)]],[eleY1Dict[str(i)],eleY1Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],layInfoDict['x.max'].value],[-1*eleY2Dict[str(i)],-1*eleY2Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([layInfoDict['x.min'].value,eleEndDict[str(i)]],[-1*eleY2Dict[str(i)],-1*eleY2Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],eleStartDict[str(i)]],[eleY1Dict[str(i)],-1*eleY2Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([eleEndDict[str(i)],eleEndDict[str(i)]],[eleY1Dict[str(i)],-1*eleY2Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
					#draw wrapped box element



					elif eleShapeDict[str(i)] == 'xbox' and eleEndDict[str(i)]-eleStartDict[str(i)] < 0:	
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],layInfoDict['x.max'].value],[eleY1Dict[str(i)],eleY1Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([layInfoDict['x.min'].value,eleEndDict[str(i)]],[eleY1Dict[str(i)],eleY1Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],layInfoDict['x.max'].value],[-1*eleY2Dict[str(i)],-1*eleY2Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([layInfoDict['x.min'].value,eleEndDict[str(i)]],[-1*eleY2Dict[str(i)],-1*eleY2Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],eleStartDict[str(i)]],[eleY1Dict[str(i)],-1*eleY2Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([eleEndDict[str(i)],eleEndDict[str(i)]],[eleY1Dict[str(i)],-1*eleY2Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],layInfoDict['x.max'].value],[eleY1Dict[str(i)],0],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([layInfoDict['x.min'].value,eleEndDict[str(i)]],[0,eleY1Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],layInfoDict['x.max'].value],[-1*eleY2Dict[str(i)],0],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([layInfoDict['x.min'].value,eleEndDict[str(i)]],[0,-1*eleY2Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
					#draw wrapped xbox element



					elif eleShapeDict[str(i)] == 'x' and eleEndDict[str(i)]-eleStartDict[str(i)] < 0:
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],layInfoDict['x.max'].value],[eleY1Dict[str(i)],0],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([layInfoDict['x.min'].value,eleEndDict[str(i)]],[0,eleY1Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],layInfoDict['x.max'].value],[-1*eleY2Dict[str(i)],0],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([layInfoDict['x.min'].value,eleEndDict[str(i)]],[0,-1*eleY2Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
					#draw wrapped x element



					elif eleShapeDict[str(i)] == 'bow_tie' and eleEndDict[str(i)]-eleStartDict[str(i)] < 0:
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],layInfoDict['x.max'].value],[eleY1Dict[str(i)],eleY1Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([layInfoDict['x.min'].value,eleEndDict[str(i)]],[eleY1Dict[str(i)],eleY1Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],layInfoDict['x.max'].value],[-1*eleY2Dict[str(i)],-1*eleY2Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([layInfoDict['x.min'].value,eleEndDict[str(i)]],[-1*eleY2Dict[str(i)],-1*eleY2Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],layInfoDict['x.max'].value],[eleY1Dict[str(i)],0],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([layInfoDict['x.min'].value,eleEndDict[str(i)]],[0,eleY1Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],layInfoDict['x.max'].value],[-1*eleY2Dict[str(i)],0],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([layInfoDict['x.min'].value,eleEndDict[str(i)]],[0,-1*eleY2Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
					#draw wrapped bow tie element						


					elif eleShapeDict[str(i)] == 'diamond' and eleEndDict[str(i)]-eleStartDict[str(i)] < 0:
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],layInfoDict['x.max'].value],[0,eleY1Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([layInfoDict['x.min'].value,eleEndDict[str(i)]],[eleY1Dict[str(i)],0],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([eleStartDict[str(i)],layInfoDict['x.max'].value],[0,-1*eleY2Dict[str(i)]],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
						GraphDict['LatLayout'].plot([layInfoDict['x.min'].value,eleEndDict[str(i)]],[-1*eleY2Dict[str(i)],0],lw=eleLwDict[str(i)],color=eleColorDict[str(i)])
					#draw wrapped diamond element



					if eleEndDict[str(i)]-eleStartDict[str(i)] > 0:			
						GraphDict['LatLayout'].text(eleStartDict[str(i)]+(eleEndDict[str(i)]-eleStartDict[str(i)])/2,-1.1*eleY2Dict[str(i)],eleNameDict[str(i)],ha='center',va='top',color=eleColorDict[str(i)])
					#draw element name



					elif eleEndDict[str(i)]-eleStartDict[str(i)] < 0:
						GraphDict['LatLayout'].text(layInfoDict['x.max'].value,-1.1*eleY2Dict[str(i)],eleNameDict[str(i)],ha='right',va='top',color=eleColorDict[str(i)])
						GraphDict['LatLayout'].text(layInfoDict['x.min'].value,-1.1*eleY2Dict[str(i)],eleNameDict[str(i)],ha='left',va='top',color=eleColorDict[str(i)])
					#draw wrapped element name

					

				except KeyError:
					pass


		else:
			GraphDict['LatLayout']=fig.add_subplot(len(gList)+1,1,len(gList)+1,sharex=GraphDict['graph1'])
			GraphDict['LatLayout'].remove()
		
		

		'''Floor Plan'''
		
		if FloorPlan == True:
			GraphDict['FloorPlan']=fig.add_subplot(len(gList)+1,1,len(gList)+1,sharex=GraphDict['graph1'])

			floInfo=pipe.cmd_in('python plot_graph r1.g').splitlines()
			#list of plotting parameter strings from tao command python plot_graph


			floInfoList = []
			floInfoDict = {}
			for i in range(len(floInfo)):
				floInfoDict[floInfo[i].split(';')[0]]=str_to_tao_param(floInfo[i])
				floInfoList.append(floInfo[i].split(';')[0])
			#list of tao_parameter object names from python plot_graph
			#dictionary of tao_parameter name string keys to the corresponding tao_parameter object

			if floInfoDict['ix_universe'].value != -1:
				universe = floInfoDict[ix_universe].value
			
			else:
				universe = 1

			fpeInfo=pipe.cmd_in('python floor_plan r1.g').splitlines()
			#list of plotting parameter strings from tao command python floor_plan
			
			
			fpeIndexList = []
			fpeTypeDict = {}
			fpeSxDict = {} #start x coordinate
			fpeSyDict = {} #start y coordinate
			fpeSaDict = {} #start angle
			fpeExDict = {} #end x coordinate
			fpeEyDict = {} #end y coordinate
			fpeEaDict = {} #end angle
			fpeLwDict = {}
			fpeShapeDict = {}
			fpeY1Dict = {} #distance above  
			fpeY2Dict = {} #distance below
			fpeColorDict = {}
			fpeNameDict = {}
			fpeAlDict = {} #arc length
			fpeBaDict = {} #bend angle
			fpeSfaDict = {} #relative angle of starting face to incoming line
			fpeEfaDict = {} #relative angle of ending face to incoming line
			for i in range(len(fpeInfo)):
				fpeIndexList.append(int(fpeInfo[i].split(';')[1]))
				fpeTypeDict[fpeInfo[i].split(';')[1]]= fpeInfo[i].split(';')[2].lower()
				fpeSxDict[fpeInfo[i].split(';')[1]]= float(fpeInfo[i].split(';')[3])
				fpeSyDict[fpeInfo[i].split(';')[1]]= float(fpeInfo[i].split(';')[4])
				fpeSaDict[fpeInfo[i].split(';')[1]]= float(fpeInfo[i].split(';')[5])
				fpeExDict[fpeInfo[i].split(';')[1]]= float(fpeInfo[i].split(';')[6])
				fpeEyDict[fpeInfo[i].split(';')[1]]= float(fpeInfo[i].split(';')[7])
				fpeEaDict[fpeInfo[i].split(';')[1]]= float(fpeInfo[i].split(';')[8])
				fpeLwDict[fpeInfo[i].split(';')[1]]= float(fpeInfo[i].split(';')[9])
				fpeShapeDict[fpeInfo[i].split(';')[1]]= fpeInfo[i].split(';')[10].lower()
				fpeY1Dict[fpeInfo[i].split(';')[1]]= float(fpeInfo[i].split(';')[11])
				fpeY2Dict[fpeInfo[i].split(';')[1]]= float(fpeInfo[i].split(';')[12])
				fpeColorDict[fpeInfo[i].split(';')[1]]= fpeInfo[i].split(';')[13].lower()
				fpeNameDict[fpeInfo[i].split(';')[1]]= fpeInfo[i].split(';')[14]
				try:
					fpeAlDict[fpeInfo[i].split(';')[1]]= float(fpeInfo[i].split(';')[15])
					fpeBaDict[fpeInfo[i].split(';')[1]]= float(fpeInfo[i].split(';')[16])
					fpeSfaDict[fpeInfo[i].split(';')[1]]= float(fpeInfo[i].split(';')[17])
					fpeEfaDict[fpeInfo[i].split(';')[1]]= float(fpeInfo[i].split(';')[18])
				except IndexError:
					pass
			#dict keys and entries are strings which match a floor plan element index (eg: '1') string to the corresponding information

			def line(p1, p2):
				'''returns lines based on given points to be used with intersect'''
				A = (p1[1] - p2[1])
				B = (p2[0] - p1[0])
				C = (p1[0]*p2[1] - p2[0]*p1[1])
				return A, B, -C

			def intersect(L1, L2):
				'''returns intersection point of 2 lines from the line funciton, or false if the lines don't intersect'''
				D = L1[0]*L2[1] - L1[1]*L2[0]
				Dx = L1[2]*L2[1] - L1[1]*L2[2]
				Dy = L1[0]*L2[2] - L1[2]*L2[0]

				if D != 0:
					x = Dx / D
					y = Dy / D
					return x,y
				else:
					return False



			conv = (180)/(np.pi) #radian to degree conversion
			for i in fpeIndexList:
				try:
					if fpeY1Dict[str(i)] == 0 and fpeY2Dict[str(i)] == 0 and fpeTypeDict[str(i)] != 'sbend' and fpeColorDict[str(i)] != '':
						GraphDict['FloorPlan'].plot([fpeSxDict[str(i)],fpeExDict[str(i)]],[fpeSyDict[str(i)],fpeEyDict[str(i)]],lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)])
					#draw line element



					elif fpeShapeDict[str(i)] == 'box' and fpeTypeDict[str(i)] != 'sbend' and fpeColorDict[str(i)] != '':
						GraphDict['FloorPlan'].add_patch(patches.Rectangle((fpeSxDict[str(i)] + fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]),fpeSyDict[str(i)] - fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)])),np.sqrt((fpeExDict[str(i)]-fpeSxDict[str(i)])**2 + (fpeEyDict[str(i)]-fpeSyDict[str(i)])**2),fpeY1Dict[str(i)]+fpeY2Dict[str(i)],lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)],fill=False,angle=fpeSaDict[str(i)]*conv))
					#draw box element



					elif fpeShapeDict[str(i)] == 'xbox' and fpeTypeDict[str(i)] != 'sbend' and fpeColorDict[str(i)] != '':
						GraphDict['FloorPlan'].add_patch(patches.Rectangle((fpeSxDict[str(i)] + fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]),fpeSyDict[str(i)] - fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)])),np.sqrt((fpeExDict[str(i)]-fpeSxDict[str(i)])**2 + (fpeEyDict[str(i)]-fpeSyDict[str(i)])**2),fpeY1Dict[str(i)]+fpeY2Dict[str(i)],lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)],fill=False,angle=fpeSaDict[str(i)]*conv))
						GraphDict['FloorPlan'].plot([fpeSxDict[str(i)] + fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]),fpeExDict[str(i)] - fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)])],[fpeSyDict[str(i)] - fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]),fpeEyDict[str(i)] + fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)])],lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)])
						GraphDict['FloorPlan'].plot([fpeSxDict[str(i)] - fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]),fpeExDict[str(i)] + fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)])],[fpeSyDict[str(i)] + fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]),fpeEyDict[str(i)] - fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)])],lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)])
					#draw xbox element



					elif fpeShapeDict[str(i)] == 'x' and fpeTypeDict[str(i)] != 'sbend' and fpeColorDict[str(i)] != '':
						GraphDict['FloorPlan'].plot([fpeSxDict[str(i)] + fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]),fpeExDict[str(i)] - fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)])],[fpeSyDict[str(i)] - fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]),fpeEyDict[str(i)] + fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)])],lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)])
						GraphDict['FloorPlan'].plot([fpeSxDict[str(i)] - fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]),fpeExDict[str(i)] + fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)])],[fpeSyDict[str(i)] + fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]),fpeEyDict[str(i)] - fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)])],lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)])
					#draw x element



					elif fpeShapeDict[str(i)] == 'bow_tie' and fpeTypeDict[str(i)] != 'sbend' and fpeColorDict[str(i)] != '':
						GraphDict['FloorPlan'].plot([fpeSxDict[str(i)] + fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]),fpeExDict[str(i)] - fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)])],[fpeSyDict[str(i)] - fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]),fpeEyDict[str(i)] + fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)])],lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)])
						GraphDict['FloorPlan'].plot([fpeSxDict[str(i)] - fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]),fpeExDict[str(i)] + fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)])],[fpeSyDict[str(i)] + fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]),fpeEyDict[str(i)] - fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)])],lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)])
						GraphDict['FloorPlan'].plot([fpeSxDict[str(i)] - fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]),fpeExDict[str(i)] - fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)])],[fpeSyDict[str(i)] + fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]),fpeEyDict[str(i)] + fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)])],lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)])
						GraphDict['FloorPlan'].plot([fpeSxDict[str(i)] + fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]),fpeExDict[str(i)] + fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)])],[fpeSyDict[str(i)] - fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]),fpeEyDict[str(i)] - fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)])],lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)])
					#draw bow_tie element



					elif fpeShapeDict[str(i)] == 'diamond' and fpeTypeDict[str(i)] != 'sbend' and fpeColorDict[str(i)] != '':
						GraphDict['FloorPlan'].plot([fpeSxDict[str(i)],fpeSxDict[str(i)] + (fpeExDict[str(i)]-fpeSxDict[str(i)])/2 - fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)])],[fpeSyDict[str(i)],fpeSyDict[str(i)] + (fpeEyDict[str(i)]-fpeSyDict[str(i)])/2 + fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)])],lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)])
						GraphDict['FloorPlan'].plot([fpeSxDict[str(i)] + (fpeExDict[str(i)]-fpeSxDict[str(i)])/2 - fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]),fpeExDict[str(i)]],[fpeSyDict[str(i)] + (fpeEyDict[str(i)]-fpeSyDict[str(i)])/2 + fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]),fpeEyDict[str(i)]],lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)])
						GraphDict['FloorPlan'].plot([fpeSxDict[str(i)],fpeSxDict[str(i)] + (fpeExDict[str(i)]-fpeSxDict[str(i)])/2 + fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)])],[fpeSyDict[str(i)],fpeSyDict[str(i)] + (fpeEyDict[str(i)]-fpeSyDict[str(i)])/2 - fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)])],lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)])
						GraphDict['FloorPlan'].plot([fpeSxDict[str(i)] + (fpeExDict[str(i)]-fpeSxDict[str(i)])/2 + fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]),fpeExDict[str(i)]],[fpeSyDict[str(i)] + (fpeEyDict[str(i)]-fpeSyDict[str(i)])/2 - fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]),fpeEyDict[str(i)]],lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)])
					#draw diamond element



					elif fpeShapeDict[str(i)] == 'circle' and fpeTypeDict[str(i)] != 'sbend' and fpeColorDict[str(i)] != '':
						GraphDict['FloorPlan'].add_patch(patches.Circle((fpeSxDict[str(i)] + (fpeExDict[str(i)]-fpeSxDict[str(i)])/2,fpeSyDict[str(i)] + (fpeEyDict[str(i)]-fpeSyDict[str(i)])/2),(np.sqrt((fpeExDict[str(i)]-fpeSxDict[str(i)])**2 + (fpeEyDict[str(i)]-fpeSyDict[str(i)])**2))/2,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)],fill=False))
					#draw circle element



					elif fpeShapeDict[str(i)] == 'box' and fpeTypeDict[str(i)] == 'sbend' and fpeColorDict[str(i)] != '':
						GraphDict['FloorPlan'].plot([fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)]),fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])],[fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)]),fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])],lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)])
						GraphDict['FloorPlan'].plot([fpeExDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeEaDict[str(i)]+fpeEfaDict[str(i)]),fpeExDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeEaDict[str(i)]+fpeEfaDict[str(i)])],[fpeEyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeEaDict[str(i)]+fpeEfaDict[str(i)]),fpeEyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeEaDict[str(i)]+fpeEfaDict[str(i)])],lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)])
						#sbend edges
						

						intersection = intersect(line([fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]),fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)])],[fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]),fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)])]), line([fpeExDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeEaDict[str(i)]),fpeEyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeEaDict[str(i)])],[fpeExDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeEaDict[str(i)]),fpeEyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeEaDict[str(i)]+fpeEfaDict[str(i)])]))



						if intersection == False:
							GraphDict['FloorPlan'].plot([fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)]),fpeExDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeEaDict[str(i)]+fpeEfaDict[str(i)])],[fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)]),fpeEyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeEaDict[str(i)]+fpeEfaDict[str(i)])],lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)])
							GraphDict['FloorPlan'].plot([fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)]),fpeExDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeEaDict[str(i)]+fpeEfaDict[str(i)])],[fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)]),fpeEyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeEaDict[str(i)]+fpeEfaDict[str(i)])],lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)])
						#zero bend angle

						


						elif intersection != False:
							angle1 = 360 + conv*np.arctan2(fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1],fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])
							angle2 = 360 + conv*np.arctan2(fpeEyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeEaDict[str(i)]+fpeEfaDict[str(i)])-intersection[1],fpeExDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeEaDict[str(i)]+fpeEfaDict[str(i)])-intersection[0])
							angle3 = 360 + conv*np.arctan2(fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1],fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])
							angle4 = 360 + conv*np.arctan2(fpeEyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeEaDict[str(i)]+fpeEfaDict[str(i)])-intersection[1],fpeExDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeEaDict[str(i)]+fpeEfaDict[str(i)])-intersection[0])
							
							if abs(angle1-angle2) < 180 and abs(angle3-angle4) < 180:
								if angle1 > angle2 and angle3 > angle4:
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle2,theta2=angle1,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle4,theta2=angle3,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
								
								elif angle1 < angle2 and angle3 > angle4:
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle1,theta2=angle2,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle4,theta2=angle3,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
								
								elif angle1 > angle2 and angle3 < angle4:
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle2,theta2=angle1,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle3,theta2=angle4,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))	

								else:
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle1,theta2=angle2,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle3,theta2=angle4,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))



							elif abs(angle1-angle2) > 180 and abs(angle3-angle4) < 180:
								if angle1 > angle2 and angle3 > angle4:
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle1,theta2=angle2,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle4,theta2=angle3,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
								
								elif angle1 < angle2 and angle3 > angle4:
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle2,theta2=angle1,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle4,theta2=angle3,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
								
								elif angle1 > angle2 and angle3 < angle4:
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle1,theta2=angle2,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle3,theta2=angle4,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))	

								else:
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle2,theta2=angle1,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle3,theta2=angle4,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))



							elif abs(angle1-angle2) < 180 and abs(angle3-angle4) > 180:
								if angle1 > angle2 and angle3 > angle4:
									print(str(i))
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle2,theta2=angle1,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle3,theta2=angle4,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
								
								elif angle1 < angle2 and angle3 > angle4:
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle1,theta2=angle2,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle3,theta2=angle4,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
								
								elif angle1 > angle2 and angle3 < angle4:
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle2,theta2=angle1,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle4,theta2=angle3,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))	

								else:
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle1,theta2=angle2,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle4,theta2=angle3,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))



							else:
								if angle1 > angle2 and angle3 > angle4:
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle1,theta2=angle2,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle3,theta2=angle4,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
								
								elif angle1 < angle2 and angle3 > angle4:
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle2,theta2=angle1,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle3,theta2=angle4,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
								
								elif angle1 > angle2 and angle3 < angle4:
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle1,theta2=angle2,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle4,theta2=angle3,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))	

								else:
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]-fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]+fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle2,theta2=angle1,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))
									GraphDict['FloorPlan'].add_patch(patches.Arc((intersection[0],intersection[1]),np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,np.sqrt((fpeSxDict[str(i)]+fpeY2Dict[str(i)]*np.sin(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[0])**2 + (fpeSyDict[str(i)]-fpeY2Dict[str(i)]*np.cos(fpeSaDict[str(i)]-fpeSfaDict[str(i)])-intersection[1])**2)*2,theta1=angle4,theta2=angle3,lw=fpeLwDict[str(i)],color=fpeColorDict[str(i)]))			
						#nonzero bend angle

					#draw sbend element



					if fpeNameDict[str(i)] != '' and fpeColorDict[str(i)] != '' and np.sin(((fpeEaDict[str(i)]+fpeSaDict[str(i)])/2)) > 0:
						GraphDict['FloorPlan'].text(fpeSxDict[str(i)]+(fpeExDict[str(i)]-fpeSxDict[str(i)])/2 - 1.3*fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]),fpeSyDict[str(i)]+(fpeEyDict[str(i)]-fpeSyDict[str(i)])/2 + 1.3*fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]),fpeNameDict[str(i)],ha='right',va='center',color='black',rotation=-90+((fpeEaDict[str(i)]+fpeSaDict[str(i)])/2)*conv,clip_on=True,rotation_mode='anchor')

					elif fpeNameDict[str(i)] != '' and fpeColorDict[str(i)] != '' and np.sin(((fpeEaDict[str(i)]+fpeSaDict[str(i)])/2)) <= 0:
						GraphDict['FloorPlan'].text(fpeSxDict[str(i)]+(fpeExDict[str(i)]-fpeSxDict[str(i)])/2 - 1.3*fpeY1Dict[str(i)]*np.sin(fpeSaDict[str(i)]),fpeSyDict[str(i)]+(fpeEyDict[str(i)]-fpeSyDict[str(i)])/2 + 1.3*fpeY1Dict[str(i)]*np.cos(fpeSaDict[str(i)]),fpeNameDict[str(i)],ha='left',va='center',color='black',rotation=90+((fpeEaDict[str(i)]+fpeSaDict[str(i)])/2)*conv,clip_on=True,rotation_mode='anchor')
					#draw element name
					


				except KeyError:
					pass

			if floInfoDict['floor_plan_orbit_scale'] != 0:
				fpoInfo=pipe.cmd_in('python floor_orbit r1.g').splitlines()
				
				fpoIndexList = []
				fpoXList = []
				fpoYList = []
				for i in range(len(fpoInfo)):
					fpoIndexList.append(int(fpoInfo[i].split(';')[1]))
					
					if fpoInfo[i].split(';')[2].lower() == 'x':
						for j in range(3,len(fpoInfo[i].split(';'))):
							fpoXList.append(float(fpoInfo[i].split(';')[j]))
					if fpoInfo[i].split(';')[2].lower() == 'y':
						for j in range(3,len(fpoInfo[i].split(';'))):
							fpoYList.append(float(fpoInfo[i].split(';')[j]))


				GraphDict['FloorPlan'].plot(fpoXList,fpoYList,color=floInfoDict['floor_plan_orbit_color'].value.lower())











			plt.xlabel(pgp_to_mpl(gInfoDict['x.label'].value))
			plt.ylabel(pgp_to_mpl(gInfoDict['y.label'].value))
			#plot floor plan axis labels

			xmajorLocator=MultipleLocator((gInfoDict['x.max'].value-gInfoDict['x.min'].value)/gInfoDict['x.major_div'].value)
			ymajorLocator=MultipleLocator((gInfoDict['y.max'].value-gInfoDict['y.min'].value)/gInfoDict['y.major_div'].value)
			GraphDict['FloorPlan'].xaxis.set_major_locator(xmajorLocator)
			GraphDict['FloorPlan'].yaxis.set_major_locator(ymajorLocator)
			GraphDict['FloorPlan'].grid(gInfoDict['draw_grid'].value,which='major',axis='both')
			plt.xlim(gInfoDict['x.min'].value,gInfoDict['x.max'].value)
			plt.ylim(gInfoDict['y.min'].value,gInfoDict['y.max'].value)
			GraphDict['FloorPlan'].set_axisbelow(True)
			#plot floor plan grid



		fig.tight_layout()
		return fig



