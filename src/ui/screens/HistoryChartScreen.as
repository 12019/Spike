package ui.screens
{
	import flash.display.StageOrientation;
	import flash.system.System;
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;
	
	import database.BlueToothDevice;
	import database.CommonSettings;
	import database.Database;
	
	import events.DatabaseEvent;
	
	import feathers.controls.Button;
	import feathers.controls.Check;
	import feathers.controls.DateTimeMode;
	import feathers.controls.DateTimeSpinner;
	import feathers.controls.Label;
	import feathers.controls.LayoutGroup;
	import feathers.controls.PanelScreen;
	import feathers.controls.Radio;
	import feathers.controls.ScrollBarDisplayMode;
	import feathers.controls.ScrollPolicy;
	import feathers.core.ToggleGroup;
	import feathers.events.FeathersEventType;
	import feathers.layout.HorizontalAlign;
	import feathers.layout.HorizontalLayout;
	import feathers.layout.VerticalAlign;
	import feathers.layout.VerticalLayout;
	import feathers.themes.BaseMaterialDeepGreyAmberMobileTheme;
	
	import model.ModelLocator;
	
	import starling.core.Starling;
	import starling.display.DisplayObject;
	import starling.events.Event;
	import starling.events.ResizeEvent;
	import starling.utils.SystemUtil;
	
	import treatments.Treatment;
	
	import ui.AppInterface;
	import ui.chart.DistributionChart;
	import ui.chart.GlucoseChart;
	import ui.chart.GraphLayoutFactory;
	import ui.chart.PieDistributionSection;
	import ui.screens.display.LayoutFactory;
	import ui.shapes.SpikeLine;
	
	import utils.Constants;
	import utils.DeviceInfo;
	
	[ResourceBundle("globaltranslations")]
	[ResourceBundle("chartscreen")]

	public class HistoryChartScreen extends PanelScreen
	{
		//Objects
		private var chartData:Array = [];
		private var chartTreatments:Array = [];
		private var timeRangeGroup:ToggleGroup;
		
		//Visual variables
		private var glucoseChartTopPadding:int = 7;
		private var selectedTimelineRange:Number;
		private var drawLineChart:Boolean;
		private var mainChartHeight:Number;
		private var availableScreenHeight:Number;
		private var chartSettingsLeftRightPadding:int = 10;
		private var chartSettingsTopPadding:int = 10;
		private var delimitterTopPadding:int = 10;
		private var pieTopPadding:int = 15;
		private var pieChartHeight:Number;
		private var displayPieChart:Boolean;
		private var redrawChartTimeoutID:int;
		private var isPortrait:Boolean;
		private var startTimestamp:Number = Number.NaN;
		private var endTimestamp:Number = Number.NaN;
		
		//Logical Variables
		private var chartRequiresReload:Boolean = true;
		private var treatmentsEnabled:Boolean = false;
		private var chartTreatmentsEnabled:Boolean = false;
		
		//Display Objects
		private var glucoseChart:GlucoseChart;
		private var pieChart:DistributionChart;
		private var h24:Radio;
		private var h12:Radio;
		private var h6:Radio;
		private var h3:Radio;
		private var h1:Radio;
		private var displayLines:Check;
		private var delimitter:SpikeLine;
		private var datePicker:DateTimeSpinner;
		private var backButton:Button;
		private var dateSelectorContainer:LayoutGroup;
		private var goButton:Button;
		private var renderingLabel:Label;
		private var renderingLabelContainer:LayoutGroup;
		
		public function HistoryChartScreen() 
		{
			super();
			
			styleNameList.add( BaseMaterialDeepGreyAmberMobileTheme.THEME_STYLE_NAME_HEADER_WITH_SHADOW );
			styleNameList.add( BaseMaterialDeepGreyAmberMobileTheme.THEME_STYLE_NAME_PANEL_WITHOUT_PADDING );
			scrollBarDisplayMode = ScrollBarDisplayMode.NONE;
			headerProperties.disposeItems = true;
			
			//Scroll Policies
			scrollBarDisplayMode = ScrollBarDisplayMode.NONE;
			horizontalScrollPolicy = ScrollPolicy.OFF;
			verticalScrollPolicy = ScrollPolicy.OFF;
			
			//Event listeners
			setupEventListeners();
		}
		
		override protected function initialize():void 
		{
			super.initialize();
			
			/* Add default back button to the header */
			backButton = new Button();
			backButton.label = ModelLocator.resourceManagerInstance.getString('globaltranslations','back');
			backButton.styleNameList.add( Button.ALTERNATE_STYLE_NAME_BACK_BUTTON );
			headerProperties.leftItems = new <DisplayObject>[backButton];
			backButton.addEventListener(Event.TRIGGERED, onBackButtonTriggered);
			
			//Set Properties From Database
			selectedTimelineRange = Number(CommonSettings.getCommonSetting(CommonSettings.COMMON_SETTING_CHART_SELECTED_TIMELINE_RANGE));
			drawLineChart = CommonSettings.getCommonSetting(CommonSettings.COMMON_SETTING_CHART_DISPLAY_LINE) == "true";
			displayPieChart = CommonSettings.getCommonSetting(CommonSettings.COMMON_SETTING_CHART_DISPLAY_GLUCOSE_DISTRIBUTION) == "true";
			treatmentsEnabled = CommonSettings.getCommonSetting(CommonSettings.COMMON_SETTING_TREATMENTS_ENABLED) == "true";
			chartTreatmentsEnabled = CommonSettings.getCommonSetting(CommonSettings.COMMON_SETTING_TREATMENTS_ON_CHART_ENABLED) == "true";
			
			//Define start and end date
			calculateTimerangeDates(new Date().valueOf());
			
			//Rendering label
			var containerLayout:VerticalLayout = new VerticalLayout();
			containerLayout.horizontalAlign = HorizontalAlign.CENTER;
			containerLayout.verticalAlign = VerticalAlign.MIDDLE;
			renderingLabelContainer = new LayoutGroup();
			renderingLabelContainer.layout = containerLayout;
			
			renderingLabel = LayoutFactory.createLabel(ModelLocator.resourceManagerInstance.getString('chartscreen','history_preloader_label'), HorizontalAlign.CENTER, VerticalAlign.MIDDLE, 14, true);
			renderingLabelContainer.addChild(renderingLabel);
			
			/* Adjust Menu */
			adjustMainMenu();
		}
		
		/**
		 * Functionality
		 */
		private function createDateSelector():void
		{
			var dateSelectorLayout:HorizontalLayout = new HorizontalLayout();
			dateSelectorLayout.verticalAlign = VerticalAlign.MIDDLE;
			dateSelectorLayout.gap = 9;
			
			dateSelectorContainer = new LayoutGroup();
			dateSelectorContainer.layout = dateSelectorLayout;
			
			var now:Date = new Date();
			var before:Date = new Date();
			before.month -= 3;
			
			datePicker = new DateTimeSpinner();
			datePicker.editingMode = DateTimeMode.DATE;
			datePicker.minimum = before;
			datePicker.maximum = now;
			datePicker.value = now;
			datePicker.maxHeight = 35;
			datePicker.scale = 0.8;
			dateSelectorContainer.addChild(datePicker);
			
			goButton = LayoutFactory.createButton(ModelLocator.resourceManagerInstance.getString('chartscreen','history_go_button_label'));
			goButton.addEventListener(Event.TRIGGERED, onDateChanged);
			dateSelectorContainer.addChild(goButton);
			
			dateSelectorContainer.validate();
			goButton.y += 2
			
			headerProperties.rightItems = new <DisplayObject>[
				dateSelectorContainer
			];
		}
		
		private function calculateTimerangeDates(baseTimestamp:Number):void
		{
			var selectedTimeStamp:Number = baseTimestamp;
			
			var startDate:Date = new Date(selectedTimeStamp);
			startDate.hours = 0;
			startDate.minutes = 0;
			startDate.seconds = 0;
			startDate.milliseconds = 0;
			
			var endDate:Date = new Date(selectedTimeStamp);
			endDate.hours = 23;
			endDate.minutes = 59;
			endDate.seconds = 59;
			endDate.milliseconds = 999;
			
			startTimestamp = startDate.valueOf();
			endTimestamp = endDate.valueOf();
		}
		
		private function getHistoricalTreatments():void
		{
			chartTreatments.length = 0;
			
			var dbTreatments:Array = Database.getTreatmentsSynchronous(startTimestamp, endTimestamp);
			if (dbTreatments != null && dbTreatments.length > 0)
			{
				for (var i:int = 0; i < dbTreatments.length; i++) 
				{
					var dbTreatment:Object = dbTreatments[i] as Object;
					if (dbTreatment == null)
						continue;
					
					var treatment:Treatment = new Treatment
						(
							dbTreatment.type,
							dbTreatment.lastmodifiedtimestamp,
							dbTreatment.insulinamount,
							dbTreatment.insulinid,
							dbTreatment.carbs,
							dbTreatment.glucose,
							dbTreatment.glucoseestimated,
							dbTreatment.note,
							null,
							dbTreatment.carbdelay,
							dbTreatment.basalduration
						);
					treatment.ID = dbTreatment.id;
					chartTreatments.push(treatment);
				}
			}
		}
		
		private function onDateChanged(e:Event):void
		{
			//Remove previous display objects
			disposeDisplayObjects();
			
			//Add rendering label
			renderingLabelContainer.width = Constants.stageWidth;
			renderingLabelContainer.height = Constants.stageHeight - this.header.height;
			addChild(renderingLabelContainer);
			
			//Clear Chart Data
			if (chartData != null) chartData.length = 0;
			if (chartTreatments != null) chartTreatments.length = 0;
			
			//Define start and end date
			calculateTimerangeDates(datePicker.value.valueOf());
			
			//Get treatments from database
			getHistoricalTreatments();
			
			//Get readings from database
			Database.instance.addEventListener(DatabaseEvent.BGREADING_RETRIEVAL_EVENT, bgReadingsReceivedFromDatabase);
			Database.getBgReadings(startTimestamp, endTimestamp);
		}
		
		private function bgReadingsReceivedFromDatabase(de:DatabaseEvent):void 
		{
			Database.instance.removeEventListener(DatabaseEvent.BGREADING_RETRIEVAL_EVENT, bgReadingsReceivedFromDatabase);
			
			chartData = de.data as Array;
			createChart();
			redrawChartForTreatmentsAndLine();
		}
		
		private function createChart():void
		{	
			//When in landscape mode and device is iPhone X, make the header height same as oher models, we don't need to worry about the extra status bar size
			if (Constants.deviceModel == DeviceInfo.IPHONE_X)
			{
				if (Constants.isPortrait)
				{
					this.header.height = 123;
					this.header.maxHeight = 123;	
				}
				else
				{
					this.header.height = 93;
					this.header.maxHeight = 93;
				}
			}
			else
			{
				this.header.height = 93;
				this.header.maxHeight = 93;
			}
			
			var availableScreenHeight:Number = Constants.stageHeight - this.header.height;
			Constants.isPortrait ? glucoseChartTopPadding = 7 : glucoseChartTopPadding = 0;
			if (Constants.deviceModel == DeviceInfo.IPHONE_2G_3G_3GS_4_4S_ITOUCH_2_3_4) glucoseChartTopPadding = 0;
			if (glucoseChartTopPadding == 0) availableScreenHeight += 7;
			if (Constants.deviceModel == DeviceInfo.IPHONE_X)
				availableScreenHeight -= 15; //To avoid lower notch
			
			mainChartHeight = availableScreenHeight;
			
			if (Constants.isPortrait || (DeviceInfo.isTablet() && CommonSettings.getCommonSetting(CommonSettings.COMMON_SETTING_SHOW_PIE_IN_LANDSCAPE) == "true"))
			{
				//Calculate timeline ranges and display line height
				mainChartHeight -= chartSettingsTopPadding; //Top padding for settings
				mainChartHeight -= calculateChartSettingsSize(); //Height of settings components
				mainChartHeight -= delimitterTopPadding; //Bottom padding for settings
				
				if (displayPieChart)
					mainChartHeight -= calculatePieChartSize();
			}
			
			//Create and setup glucose chart
			var chartWidth:Number = Constants.stageWidth;
			var chartX:Number = 0;
			if (Constants.deviceModel == DeviceInfo.IPHONE_X && !Constants.isPortrait)
			{
				chartWidth -= 40;
				if (Constants.currentOrientation == StageOrientation.ROTATED_RIGHT)
					chartX = 30;
				else if (Constants.currentOrientation == StageOrientation.ROTATED_LEFT)
					chartX = 10;
			}
			
			glucoseChart = new GlucoseChart(selectedTimelineRange, chartWidth, mainChartHeight, true, true, true, true);
			glucoseChart.x = Math.round(chartX);
			glucoseChart.y = Math.round(glucoseChartTopPadding);
			glucoseChart.dataSource = chartData;
			glucoseChart.displayLine = drawLineChart;
			glucoseChart.drawGraph();
			glucoseChart.addAllHistoricalTreatments(chartTreatments);
			renderingLabelContainer.removeFromParent();
			addChild(glucoseChart);
			
			if (Constants.isPortrait || (DeviceInfo.isTablet() && CommonSettings.getCommonSetting(CommonSettings.COMMON_SETTING_SHOW_PIE_IN_LANDSCAPE) == "true"))
			{
				createSettings();
				
				if (displayPieChart)
					createPieChart();
			}
			
			Constants.headerHeight = this.header.maxHeight;
		}
		
		private function redrawChart():void
		{
			if (SystemUtil.isApplicationActive)
			{
				chartData = glucoseChart.dataSource;
				
				//Remove previous chart
				removeChild(glucoseChart);
				glucoseChart.dispose();
				glucoseChart = null;
				
				var chartWidth:Number = Constants.stageWidth;
				var chartX:Number = 0;
				if (Constants.deviceModel == DeviceInfo.IPHONE_X && !Constants.isPortrait)
				{
					chartWidth -= 40;
					if (Constants.currentOrientation == StageOrientation.ROTATED_RIGHT)
						chartX = 30;
					else if (Constants.currentOrientation == StageOrientation.ROTATED_LEFT)
						chartX = 10;
				}
				
				//Create new chart
				glucoseChart = new GlucoseChart(selectedTimelineRange, chartWidth, mainChartHeight, true, true, true, true);
				glucoseChart.x = Math.round(chartX);
				glucoseChart.y = Math.round(glucoseChartTopPadding);
				glucoseChart.dataSource = chartData;
				glucoseChart.displayLine = drawLineChart;
				glucoseChart.drawGraph();
				glucoseChart.addAllHistoricalTreatments(chartTreatments);
				addChild(glucoseChart);
			}
			else
				SystemUtil.executeWhenApplicationIsActive( redrawChartForTreatmentsAndLine );
		}
		
		private function createSettings():void
		{
			//Position Radio/Check Buttons
			var paddingMultiplier:Number = DeviceInfo.getHorizontalPaddingMultipier();
			
			h24.x = stage.stageWidth - h24.width - chartSettingsLeftRightPadding;
			h24.y = glucoseChart.y + mainChartHeight + chartSettingsTopPadding;
			addChild(h24);
			
			h12.x = h24.x - h12.width - (chartSettingsLeftRightPadding * paddingMultiplier);
			h12.y = h24.y;
			addChild(h12);
			
			h6.x = h12.x - h6.width - (chartSettingsLeftRightPadding * paddingMultiplier);
			h6.y = h24.y;
			addChild(h6);
			
			h3.x = h6.x - h3.width - (chartSettingsLeftRightPadding * paddingMultiplier);
			h3.y = h24.y;
			addChild(h3);
			
			h1.x = h3.x - h1.width - (chartSettingsLeftRightPadding * paddingMultiplier);
			h1.y = h24.y;
			addChild(h1);
			
			displayLines.x = chartSettingsLeftRightPadding;
			displayLines.y = h24.y;
			addChild(displayLines);
			
			//Radio Buttons Group
			if (selectedTimelineRange == GlucoseChart.TIMELINE_1H)
				timeRangeGroup.selectedItem = h1;
			else if (selectedTimelineRange == GlucoseChart.TIMELINE_3H)
				timeRangeGroup.selectedItem = h3;
			else if (selectedTimelineRange == GlucoseChart.TIMELINE_6H)
				timeRangeGroup.selectedItem = h6;
			else if (selectedTimelineRange == GlucoseChart.TIMELINE_12H)
				timeRangeGroup.selectedItem = h12;
			else if (selectedTimelineRange == GlucoseChart.TIMELINE_24H)
				timeRangeGroup.selectedItem = h24;
			
			//Add Event Listener For Radios
			timeRangeGroup.addEventListener( Event.CHANGE, onTimeRangeChange );
		}
		
		private function createPieChart():void
		{
			delimitter = GraphLayoutFactory.createHorizontalLine(Constants.stageWidth, 1, 0x282a32);
			delimitter.y = h24.y + h24.height + delimitterTopPadding;
			addChild(delimitter);
			
			pieChart = new DistributionChart((pieChartHeight / 2), chartData, startTimestamp, endTimestamp);
			pieChart.y = Math.round(delimitter.y + delimitter.height + pieTopPadding);
			pieChart.x = 10;
			addChild(pieChart);
		}
		
		private function redrawChartForTreatmentsAndLine():void
		{
			redrawChartTimeoutID = setTimeout(redrawChart, 1500);
		}
		
		private function calculateChartSettingsSize():Number
		{
			var chartSettingsHeight:Number = 0;
			
			/* Line Settings */
			displayLines = LayoutFactory.createCheckMark(false, ModelLocator.resourceManagerInstance.getString('chartscreen','check_box_line_title'));
			if (Constants.deviceModel == DeviceInfo.IPHONE_2G_3G_3GS_4_4S_ITOUCH_2_3_4)
				displayLines.scale = 0.8;
			else if (Constants.deviceModel == DeviceInfo.IPAD_1_2_3_4_5_AIR1_2_PRO_97 || Constants.deviceModel == DeviceInfo.IPAD_PRO_105 || Constants.deviceModel == DeviceInfo.IPAD_PRO_129)
				displayLines.scale = 1.4;
			displayLines.isSelected = drawLineChart;
			displayLines.addEventListener( Event.CHANGE, onDisplayLine );
			displayLines.validate();
			
			chartSettingsHeight = displayLines.height;
			
			/* Timeline Settings */
			timeRangeGroup = new ToggleGroup();
			
			//Create Radios
			h1 = LayoutFactory.createRadioButton(ModelLocator.resourceManagerInstance.getString('chartscreen','radio_button_1h_title'), timeRangeGroup);
			if (Constants.deviceModel == DeviceInfo.IPHONE_2G_3G_3GS_4_4S_ITOUCH_2_3_4)
				h1.scale = 0.8;
			else if (Constants.deviceModel == DeviceInfo.IPAD_1_2_3_4_5_AIR1_2_PRO_97 || Constants.deviceModel == DeviceInfo.IPAD_PRO_105 || Constants.deviceModel == DeviceInfo.IPAD_PRO_129)
				h1.scale = 1.4;
			h1.validate();
			
			h3 = LayoutFactory.createRadioButton(ModelLocator.resourceManagerInstance.getString('chartscreen','radio_button_3h_title'), timeRangeGroup);
			if (Constants.deviceModel == DeviceInfo.IPHONE_2G_3G_3GS_4_4S_ITOUCH_2_3_4)
				h3.scale = 0.8;
			else if (Constants.deviceModel == DeviceInfo.IPAD_1_2_3_4_5_AIR1_2_PRO_97 || Constants.deviceModel == DeviceInfo.IPAD_PRO_105 || Constants.deviceModel == DeviceInfo.IPAD_PRO_129)
				h3.scale = 1.4;
			h3.validate();
			
			h6 = LayoutFactory.createRadioButton(ModelLocator.resourceManagerInstance.getString('chartscreen','radio_button_6h_title'), timeRangeGroup);
			if (Constants.deviceModel == DeviceInfo.IPHONE_2G_3G_3GS_4_4S_ITOUCH_2_3_4)
				h6.scale = 0.8;
			else if (Constants.deviceModel == DeviceInfo.IPAD_1_2_3_4_5_AIR1_2_PRO_97 || Constants.deviceModel == DeviceInfo.IPAD_PRO_105 || Constants.deviceModel == DeviceInfo.IPAD_PRO_129)
				h6.scale = 1.4;
			h6.validate();
			
			h12 = LayoutFactory.createRadioButton(ModelLocator.resourceManagerInstance.getString('chartscreen','radio_button_12h_title'), timeRangeGroup);
			if (Constants.deviceModel == DeviceInfo.IPHONE_2G_3G_3GS_4_4S_ITOUCH_2_3_4)
				h12.scale = 0.8;
			else if (Constants.deviceModel == DeviceInfo.IPAD_1_2_3_4_5_AIR1_2_PRO_97 || Constants.deviceModel == DeviceInfo.IPAD_PRO_105 || Constants.deviceModel == DeviceInfo.IPAD_PRO_129)
				h12.scale = 1.4;
			h12.validate();
			
			h24 = LayoutFactory.createRadioButton(ModelLocator.resourceManagerInstance.getString('chartscreen','radio_button_24h_title'), timeRangeGroup);
			if (Constants.deviceModel == DeviceInfo.IPHONE_2G_3G_3GS_4_4S_ITOUCH_2_3_4)
				h24.scale = 0.8;
			else if (Constants.deviceModel == DeviceInfo.IPAD_1_2_3_4_5_AIR1_2_PRO_97 || Constants.deviceModel == DeviceInfo.IPAD_PRO_105 || Constants.deviceModel == DeviceInfo.IPAD_PRO_129)
				h24.scale = 1.4;
			h24.validate();
			
			return chartSettingsHeight;
		}
		
		private function calculatePieChartSize():Number
		{
			var pieChartTotalHeight:Number = 0;
			
			if (Constants.deviceModel == DeviceInfo.IPHONE_2G_3G_3GS_4_4S_ITOUCH_2_3_4)
				pieTopPadding = 10;
			
			pieChartTotalHeight += pieTopPadding * 2;
			
			var dummyPieChartStatsSection:PieDistributionSection = new PieDistributionSection(100, 30, 0x000000, 0x000000, 0x000000);
			dummyPieChartStatsSection.title.text = "N/A";
			dummyPieChartStatsSection.title.validate();
			dummyPieChartStatsSection.message.text = "N/A";
			dummyPieChartStatsSection.message.validate();
			
			var sectionMultiplier:Number = 3;
			if (Constants.deviceModel == DeviceInfo.IPHONE_2G_3G_3GS_4_4S_ITOUCH_2_3_4)
				sectionMultiplier = 2.5;
			else if (Constants.deviceModel == DeviceInfo.IPHONE_X)
				sectionMultiplier = 3.1;
			
			pieChartHeight = (sectionMultiplier * dummyPieChartStatsSection.title.height) + (sectionMultiplier * dummyPieChartStatsSection.message.height);
			
			dummyPieChartStatsSection.dispose();
			dummyPieChartStatsSection = null;
			
			pieChartTotalHeight += pieChartHeight;
			
			return pieChartTotalHeight;
		}
		
		private function setupEventListeners():void
		{
			this.addEventListener(FeathersEventType.TRANSITION_IN_COMPLETE, onTransitionInComplete);
			this.addEventListener(FeathersEventType.TRANSITION_OUT_COMPLETE, onBackButtonTriggered);
			Starling.current.stage.addEventListener(starling.events.Event.RESIZE, onStarlingResize);
			addEventListener(FeathersEventType.CREATION_COMPLETE, onCreation);
		}
		
		private function adjustMainMenu():void
		{
			if (!BlueToothDevice.isFollower())
				AppInterface.instance.menu.selectedIndex = 6;
			else
				AppInterface.instance.menu.selectedIndex = 4;
		}
		
		/**
		 * Event Handlers
		 */
		private function onCreation(event:Event):void
		{
			createDateSelector();
			
			//Initial treaments data
			getHistoricalTreatments();
			
			//Get readings from database
			Database.instance.addEventListener(DatabaseEvent.BGREADING_RETRIEVAL_EVENT, bgReadingsReceivedFromDatabase);
			Database.getBgReadings(startTimestamp, endTimestamp);
		}
		
		private function onDisplayLine(event:Event):void
		{
			var check:Check = Check( event.currentTarget );
			if(check.isSelected)
			{
				glucoseChart.showLine();
				drawLineChart = true;
			}
			else
			{
				glucoseChart.hideLine();
				drawLineChart = false;
			}
			
			//Save setting to database
			if (drawLineChart)
				CommonSettings.setCommonSetting(CommonSettings.COMMON_SETTING_CHART_DISPLAY_LINE, "true");
			else
				CommonSettings.setCommonSetting(CommonSettings.COMMON_SETTING_CHART_DISPLAY_LINE, "false");
		}
		
		private function onTimeRangeChange(event:Event):void
		{
			var group:ToggleGroup = ToggleGroup( event.currentTarget );
			if (group.selectedIndex == 0)
			{
				//1H
				selectedTimelineRange = GlucoseChart.TIMELINE_1H;
				redrawChart();
			}
			else if (group.selectedIndex == 1)
			{
				//3H
				selectedTimelineRange = GlucoseChart.TIMELINE_3H;
				redrawChart();
			}
			else if (group.selectedIndex == 2)
			{
				//6H
				selectedTimelineRange = GlucoseChart.TIMELINE_6H;
				redrawChart();
			}
			else if (group.selectedIndex == 3)
			{
				//12H
				selectedTimelineRange = GlucoseChart.TIMELINE_12H;
				redrawChart();
			}
			else if (group.selectedIndex == 4)
			{
				//24H
				selectedTimelineRange = GlucoseChart.TIMELINE_24H;
				redrawChart();
			}
		}
		
		private function onBackButtonTriggered(event:Event):void
		{
			//Pop this screen off
			dispatchEventWith(Event.COMPLETE);
			
			if(AppInterface.instance.navigator.activeScreenID == Screens.GLUCOSE_CHART)
			{
				//Select menu button from left menu
				AppInterface.instance.menu.selectedIndex = 0;
			}
			
		}
		
		private function onStarlingResize(event:ResizeEvent):void 
		{
			if (renderingLabelContainer != null)
			{
				renderingLabelContainer.width = Constants.stageWidth;
				renderingLabelContainer.height = Constants.stageHeight - this.header.height;
			}
			SystemUtil.executeWhenApplicationIsActive(disposeDisplayObjects);
			SystemUtil.executeWhenApplicationIsActive(createChart);
		}
		
		protected function onTransitionInComplete(e:Event):void
		{
			//Swipe to pop functionality
			AppInterface.instance.navigator.isSwipeToPopEnabled = false;
		}
		
		/**
		 * Utility
		 */
		private function disposeDisplayObjects():void
		{
			/* Display Objects */
			if (glucoseChart != null)
			{
				glucoseChart.removeFromParent();
				glucoseChart.dispose();
				glucoseChart = null;
			}
			
			if (pieChart != null)
			{
				pieChart.removeFromParent();
				pieChart.dispose();
				pieChart = null;
			}
			
			if (timeRangeGroup != null)
			{
				timeRangeGroup.removeEventListener( Event.CHANGE, onTimeRangeChange );
				timeRangeGroup = null;
			}
			
			if (h24 != null)
			{
				h24.removeFromParent();
				h24.dispose();
				h24 = null;
			}
			
			if (h12 != null)
			{
				h12.removeFromParent();
				h12.dispose();
				h12 = null;
			}
			
			if (h6 != null)
			{
				h6.removeFromParent();
				h6.dispose();
				h6 = null;
			}
			
			if (h3 != null)
			{
				h3.removeFromParent();
				h3.dispose();
				h3 = null;
			}
			
			if (h1 != null)
			{
				h1.removeFromParent();
				h1.dispose();
				h1 = null;
			}
			
			if (displayLines != null)
			{
				displayLines.removeEventListener( Event.CHANGE, onDisplayLine );
				displayLines.removeFromParent();
				displayLines.dispose();
				displayLines = null;
			}
			
			if (delimitter != null)
			{
				delimitter.removeFromParent();
				delimitter.dispose();
				delimitter = null;
			}
		}
		
		private function disposeHeaderObjects():void
		{
			if (goButton != null)
			{
				goButton.removeEventListener( Event.CHANGE, onDateChanged );
				goButton.removeFromParent();
				goButton.dispose();
				goButton = null;
			}
			
			if (datePicker != null)
			{
				datePicker.removeFromParent();
				datePicker.dispose();
				datePicker = null;
			}
			
			if (dateSelectorContainer != null)
			{
				dateSelectorContainer.dispose();
				dateSelectorContainer = null;
			}
			
			if (backButton != null)
			{
				backButton.removeEventListener(Event.TRIGGERED, onBackButtonTriggered);
				backButton.dispose();
				backButton = null;
			}
		}
		
		private function disposePreloader():void
		{
			if (renderingLabel != null)
			{
				renderingLabel.removeFromParent();
				renderingLabel.dispose();
				renderingLabel = null;
			}
			
			if (renderingLabelContainer != null)
			{
				renderingLabelContainer.removeFromParent();
				renderingLabelContainer.dispose();
				renderingLabelContainer = null;
			}
		}
		
		override public function dispose():void
		{
			/* Timers */
			clearTimeout(redrawChartTimeoutID);
			
			/* Event Listeners */
			removeEventListener(FeathersEventType.TRANSITION_IN_COMPLETE, onTransitionInComplete);
			removeEventListener(FeathersEventType.TRANSITION_OUT_COMPLETE, onBackButtonTriggered);
			Starling.current.stage.removeEventListener(starling.events.Event.RESIZE, onStarlingResize);
			removeEventListener(FeathersEventType.CREATION_COMPLETE, onCreation);
			
			/* Display Objects */
			SystemUtil.executeWhenApplicationIsActive(disposeDisplayObjects);
			SystemUtil.executeWhenApplicationIsActive(disposeHeaderObjects);
			SystemUtil.executeWhenApplicationIsActive(disposePreloader);
			
			/* Objects */
			if (chartData != null)
			{
				chartData.length = 0;
				chartData = null;
			}
			
			if (chartTreatments != null)
			{
				chartTreatments.length = 0;
				chartTreatments = null;
			}
			
			super.dispose();
			
			System.pauseForGCIfCollectionImminent(0);
		}
		
		override protected function draw():void 
		{
			super.draw();
			if (dateSelectorContainer != null)
				dateSelectorContainer.x = Constants.stageWidth - dateSelectorContainer.width - BaseMaterialDeepGreyAmberMobileTheme.defaultPanelPadding;
		}
	}
}