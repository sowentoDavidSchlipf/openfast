    MODULE LidarSim_Subs

    USE LidarSim_Types
    USE NWTC_Library
    USE InflowWind_Subs
    USE InflowWind_Types

    IMPLICIT NONE
    PRIVATE
    
    PUBLIC  ::  LidarSim_ReadInputFile
    PUBLIC  ::  LidarSim_InitMeasuringPoints_Cartesian
    PUBLIC  ::  LidarSim_TransformLidarToInertial
    PUBLIC  ::  LidarSim_InitMeasuringPoints_Spherical
    PUBLIC  ::  LidarSim_CreateRotationMatrix
    PUBLIC  ::  LidarSim_InitializeWeightingGauss
    PUBLIC  ::  LidarSim_InitializeWeightingManual
    PUBLIC  ::  LidarSim_CalculateVlos
    PUBLIC  ::  LidarSim_InitializeOutputs
    PUBLIC  ::  LidarSim_SetOutputs
    PUBLIC  ::  LidarSim_CalculateIMU

    CONTAINS
    
	
!#########################################################################################################################################################################
    
    SUBROUTINE LidarSim_ReadInputFile(InputInitFile, EchoFileName, InputFileData, ErrStat, ErrMsg)
	
    IMPLICIT                                NONE
    CHARACTER(*),                           PARAMETER       ::  RoutineName="LidarSim_ReadInputFile"
    
    CHARACTER(1024),                        INTENT(IN   )   ::  InputInitFile       !< Name of the Input File
    CHARACTER(*),                           INTENT(IN   )   ::  EchoFileName        !< name of the echo file 
    TYPE(LidarSim_InputFile),               INTENT(INOUT)   ::  InputFileData
    INTEGER(IntKi),                         INTENT(  OUT)   ::  ErrStat             !< Error status of the operation
    CHARACTER(*),                           INTENT(  OUT)   ::  ErrMsg              !< Error message if ErrStat /= ErrID_None
    
    ! Local variables
    REAL(ReKi)                                              ::  RotationAngle       !< Variable to temporary store the rotation angle (roll, pitch or yaw)
    REAL(ReKi)                                              ::  Rotations(3,3,3)    !< DCMs for roll, pitch and yaw
    INTEGER(IntKi)                                          ::  UnitInput           !< Unit number for the input file
    INTEGER(IntKi)                                          ::  TemporaryFileUnit   !< Unit number for the same input file. opened twice to check for out commented variables
    INTEGER(IntKi)                                          ::  UnitEcho            !< The local unit number for this module's echo file
    LOGICAL                                                 ::  CommentLine         !< True if line is commented out
    CHARACTER(1024)                                         ::  ReadLine            !< Temporary variable to Read a Line in
    INTEGER(IntKi)                                          ::  CounterNumberOfPoints_Cartesian !< Loop counter for the cartesian coordinates
    INTEGER(IntKi)                                          ::  CounterNumberOfPoints_Spherical !< Loop counter for the spherical coordinates    
    INTEGER(IntKi)                                          ::  CounterNumberManualWeighting    !< Loop counter for the manual weighting points
    INTEGER(IntKi)                                          ::  TmpErrStat
    CHARACTER(ErrMsgLen)                                    ::  TmpErrMsg           !< temporary error message
    INTEGER(IntKi)                                          ::  ErrStatIO           !< temporary error for read commands
    
    ! Initialization 
    ErrStat        =  0
    ErrMsg         =  ""
    UnitEcho       = -1
    
    ! Allocate OutList space
    CALL AllocAry( InputFileData%OutList, 18, "InflowWind Input File's OutList", TmpErrStat, TmpErrMsg ) !Max additional output parameters = 18
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
	
    !-------------------------------------------------------------------------------------------------
    ! Open the file
    !-------------------------------------------------------------------------------------------------

    CALL GetNewUnit( UnitInput, TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL OpenFInpFile( UnitInput, TRIM(InputInitFile), TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
    CALL GetNewUnit( TemporaryFileUnit, TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL OpenFInpFile( TemporaryFileUnit, TRIM(InputInitFile), TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
	
    !-------------------------------------------------------------------------------------------------
    ! File header
    !-------------------------------------------------------------------------------------------------
	
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadCom( UnitInput, InputInitFile, 'Lidar version', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
  
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg)
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    CALL ReadCom( UnitInput, InputInitFile, 'description', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadCom( UnitInput, InputInitFile, '-------------', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF

	
    !-------------------------------------------------------------------------------------------------
    ! General settings
    !-------------------------------------------------------------------------------------------------    
	
    ! Echo on/off
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadVar ( UnitInput, InputInitFile, InputFileData%Echo, 'Echo', ' Echo input data to <RootName>.ech (flag)', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
    IF ( InputFileData%Echo ) THEN
        CALL OpenEcho ( UnitEcho, TRIM(EchoFileName), TmpErrStat, TmpErrMsg )
        CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
        IF (ErrStat >= AbortErrLev) THEN
            CALL CleanUp()
            RETURN
        END IF
    
        REWIND(UnitInput)
        REWIND(TemporaryFileUnit)
    
        CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
        CALL ReadCom( UnitInput, InputInitFile, 'Lidar version', TmpErrStat, TmpErrMsg )
        CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    
        CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
        CALL ReadCom( UnitInput, InputInitFile, 'description', TmpErrStat, TmpErrMsg )
        CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    
        CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
        CALL ReadCom( UnitInput, InputInitFile, '-------------', TmpErrStat, TmpErrMsg )
        CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    
        CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
        CALL ReadVar ( UnitInput, InputInitFile, InputFileData%Echo, 'Echo', 'Echo input data to <RootName>.ech (flag)', TmpErrStat, TmpErrMsg)
        CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    
    END IF
    
    ! MAXDLLChainOutputs
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadVar ( UnitInput, InputInitFile, InputFileData%MAXDLLChainOutputs, 'MAXDLLChainOutputs', 'Number of entries in the avrSWAP reserved for the DLL chain', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
	
    !-------------------------------------------------------------------------------------------------
    ! Lidar Configuration
    !-------------------------------------------------------------------------------------------------
	
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadCom( UnitInput, InputInitFile, 'Lidar input file separator line', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF    
    
    ! Trajectory Type
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName ) 
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadVar ( UnitInput, InputInitFile, InputFileData%TrajectoryType, 'TrajectoryType', 'Switch : {0 = cartesian coordinates; 1 = spherical coordinates}', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
    ! Weighting Type
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadVar ( UnitInput, InputInitFile, InputFileData%WeightingType, 'WeightingType', 'Switch : {0 = single point; 1 = gaussian distribution}', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
        
    ! Position of the lidar system
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadVar ( UnitInput, InputInitFile, InputFileData%LidarPositionX_N, 'LidarPositionX_N', 'Position of the lidar system (X coordinate) [m]', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadVar ( UnitInput, InputInitFile, InputFileData%LidarPositionY_N, 'LidarPositionY_N', 'Position of the lidar system (Y coordinate) [m]', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadVar ( UnitInput, InputInitFile, InputFileData%LidarPositionZ_N, 'LidarPositionZ_N', 'Position of the lidar system (Z coordinate) [m]', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
    ! Rotation of the lidar system    
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadVar ( UnitInput, InputInitFile, InputFileData%RollAngle_N, 'Roll_N', 'Roll angle between the Nacelle and the lidar coordinate system', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    InputFileData%RollAngle_N = InputFileData%RollAngle_N * (Pi_D/180)    
    
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadVar ( UnitInput, InputInitFile, InputFileData%PitchAngle_N, 'Pitch_N', 'Pitch angle between the Nacelle and the lidar coordinate system', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    InputFileData%PitchAngle_N = InputFileData%PitchAngle_N * (Pi_D/180)

    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadVar ( UnitInput, InputInitFile, InputFileData%YawAngle_N, 'Yaw_N', 'Yaw Pitch angle between the Nacelle and the lidar coordinate system', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    InputFileData%YawAngle_N = InputFileData%YawAngle_N * (Pi_D/180)
    
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadVar ( UnitInput, InputInitFile, InputFileData%URef, 'URef', 'Mean u-component wind speed at the reference height', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadVar ( UnitInput, InputInitFile, InputFileData%GatesPerBeam, 'GatesPerBeam', 'Amount of gates per point', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
	
    !-------------------------------------------------------------------------------------------------
    ! Measurement settings
    !-------------------------------------------------------------------------------------------------
	
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadVar ( UnitInput, InputInitFile, InputFileData%t_measurement_interval, 't_measurement_interval', 'Time between each measurement [s]', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
       
	
	 !-------------------------------------------------------------------------------------------------
    ! Cartesian coordinates
    !-------------------------------------------------------------------------------------------------
	
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadCom( UnitInput, InputInitFile, 'cartesian coordinates', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
    ! Number of cartesian points
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadVar ( UnitInput, InputInitFile, InputFileData%NumberOfPoints_Cartesian, 'NumberOfPoints_Cartesian', 'Amount of Points [-]', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
    ! Table header
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadCom( UnitInput, InputInitFile, 'Table Header', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
    CALL AllocAry( InputFileData%X_Cartesian_L, InputFileData%NumberOfPoints_Cartesian, 'X Coordinate', TmpErrStat, TmpErrMsg )
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    CALL AllocAry( InputFileData%Y_Cartesian_L, InputFileData%NumberOfPoints_Cartesian, 'Y Coordinate', TmpErrStat, TmpErrMsg )
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    CALL AllocAry( InputFileData%Z_Cartesian_L, InputFileData%NumberOfPoints_Cartesian, 'Z Coordinate', TmpErrStat, TmpErrMsg )
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    
    ! Loop through table
    DO CounterNumberOfPoints_Cartesian = 1,InputFileData%NumberOfPoints_Cartesian
        CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
        CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
        IF (ErrStat >= AbortErrLev) THEN
            CALL Cleanup()
            RETURN
        END IF
        READ(UnitInput,*,IOSTAT=ErrStatIO) InputFileData%X_Cartesian_L(CounterNumberOfPoints_Cartesian),&
        InputFileData%Y_Cartesian_L(CounterNumberOfPoints_Cartesian),InputFileData%Z_Cartesian_L(CounterNumberOfPoints_Cartesian)
        IF( ErrStatIO > 0 ) THEN
            CALL SetErrStat(ErrID_Fatal,'Error reading cartesian coordinates',ErrStat,ErrMsg,RoutineName)
            CALL Cleanup()
            RETURN
        END IF
    END DO
    
	 
    !-------------------------------------------------------------------------------------------------
    ! Spherical coordinates
    !-------------------------------------------------------------------------------------------------
	
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadCom( UnitInput, InputInitFile, 'spherical coordinates', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
    ! Number of spherical points
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadVar ( UnitInput, InputInitFile, InputFileData%NumberOfPoints_Spherical, 'NumberOfPoints_Spherical', 'Amount of Points [-]', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
        
    ! Table header
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadCom( UnitInput, InputInitFile, 'Table Header', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
    CALL AllocAry( InputFileData%Azimuth, InputFileData%NumberOfPoints_Spherical, 'Azimuth', TmpErrStat, TmpErrMsg )
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    CALL AllocAry( InputFileData%Elevation, InputFileData%NumberOfPoints_Spherical, 'Elevation', TmpErrStat, TmpErrMsg )
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    CALL AllocAry( InputFileData%Range, InputFileData%NumberOfPoints_Spherical,InputFileData%GatesPerBeam , 'Range', TmpErrStat, TmpErrMsg )
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    
    ! Loop through spherical data table
    DO CounterNumberOfPoints_Spherical = 1, InputFileData%NumberOfPoints_Spherical
        ! Reading the number, azimuth and elevation in the corresponding variables.
		  ! The left over parameters (1..n) are read into the range variable
        ! This allows multiple range measurements with the same azimuth / elevation
        CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
        CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
        IF (ErrStat >= AbortErrLev) THEN
            CALL Cleanup()
            RETURN
        END IF
        READ(UnitInput,*,IOSTAT=ErrStatIO) InputFileData%Azimuth(CounterNumberOfPoints_Spherical),&
        InputFileData%Elevation(CounterNumberOfPoints_Spherical),InputFileData%Range(CounterNumberOfPoints_Spherical,:) 
        IF( ErrStatIO > 0 ) THEN
            CALL SetErrStat(ErrID_Fatal,'Error reading spherical coordinates',ErrStat,ErrMsg,RoutineName)
            CALL Cleanup()
            RETURN
        END IF
    END DO
    InputFileData%Azimuth   = InputFileData%Azimuth * (Pi_D/180)
    InputFileData%Elevation = InputFileData%Elevation * (Pi_D/180)
	
    
    !-------------------------------------------------------------------------------------------------
    ! Gaussian distribution
    !-------------------------------------------------------------------------------------------------    
	
    ! Description
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadCom( UnitInput, InputInitFile, 'Weighting function Gauss', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF

    ! FWHM
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadVar ( UnitInput, InputInitFile, InputFileData%FWHM, 'FWHM', 'Width of half maximum', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
    ! Number of points to evaluate
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadVar ( UnitInput, InputInitFile, InputFileData%PointsToEvaluate, 'PointsToEvaluate', 'points evaluated to "integrate" (odd number so there is a point in the peak', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
    
    !-------------------------------------------------------------------------------------------------
    ! Manual distribution
    !-------------------------------------------------------------------------------------------------    
	
    ! Description
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadCom( UnitInput, InputInitFile, 'Weighting function Manual', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
    ! Number of manual weighting points
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadVar ( UnitInput, InputInitFile, InputFileData%ManualWeightingPoints, 'ManualWeightingPoints', 'Number manual weightingpoints', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
    ! Table header
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadCom( UnitInput, InputInitFile, 'Table header', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
    CALL AllocAry( InputFileData%ManualWeightingDistance, InputFileData%ManualWeightingPoints, 'ManualWeightingDistance', TmpErrStat, TmpErrMsg )
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    CALL AllocAry( InputFileData%ManualWeighting, InputFileData%ManualWeightingPoints, 'ManualWeighting', TmpErrStat, TmpErrMsg )
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    
    ! Loop through manual weighting data table
    DO CounterNumberManualWeighting = 1, InputFileData%ManualWeightingPoints
        CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
        CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
        IF (ErrStat >= AbortErrLev) THEN
            CALL Cleanup()
            RETURN
        END IF
        READ(UnitInput,*,IOSTAT=ErrStatIO) InputFileData%ManualWeightingDistance(CounterNumberManualWeighting), InputFileData%ManualWeighting(CounterNumberManualWeighting)
        IF( ErrStatIO > 0 ) THEN
            CALL SetErrStat(ErrID_Fatal,'Error reading manual weighting',ErrStat,ErrMsg,RoutineName)
            CALL Cleanup()
            RETURN
        END IF
    END DO
    
    ! OutList
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadCom( UnitInput, InputInitFile, 'Outlist headline', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    CALL ReadCom( UnitInput, InputInitFile, 'Outlist', TmpErrStat, TmpErrMsg )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
    ! Read OutputList
    CALL LidarSim_ReadOutputList (TemporaryFileUnit, UnitInput, InputInitFile, InputFileData%OutList, InputFileData%NumOuts, 'OutList',"List of user-requested output channels", TmpErrStat, TmpErrMsg,-1 )
    CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, RoutineName )
    IF (ErrStat >= AbortErrLev) THEN
        CALL Cleanup()
        RETURN
    END IF
    
    CALL Cleanup()
    
    RETURN
	
    CONTAINS
	
    !-------------------------------------------------------------------------------------------------
    SUBROUTINE Cleanup()
	
    CLOSE ( UnitInput )
    CLOSE ( TemporaryFileUnit )
    IF ( InputFileData%Echo ) THEN
        CLOSE(UnitEcho)
    END IF
	
    END SUBROUTINE Cleanup
	!-------------------------------------------------------------------------------------------------
    
    END SUBROUTINE LidarSim_ReadInputFile
    
	
!#########################################################################################################################################################################
   
    SUBROUTINE LidarSim_ReadOutputList (TemporaryFileUnit, UnitInput, FileName, OutputArray, ReadNumberOutputs, VariableName, VariableDescribtion, ErrStat, ErrMsg, UnitEcho )
    
    IMPLICIT      NONE
    CHARACTER(*), PARAMETER           ::  RoutineName="LidarSim_ReadOutputList"
	
    INTEGER,      INTENT(  OUT)       :: ReadNumberOutputs                          !< Length of the array that was actually read.
    INTEGER,      INTENT(IN   )       :: TemporaryFileUnit                          !< Temporary unit for skipping comments
    INTEGER,      INTENT(IN   )       :: UnitInput                                  !< I/O unit for input file.
    INTEGER,      INTENT(IN   )       :: UnitEcho                                   !< I/O unit for echo file (if > 0).
    INTEGER,      INTENT(  OUT)       :: ErrStat                                    !< Error status
    CHARACTER(*), INTENT(  OUT)       :: ErrMsg                                     !< Error message
    CHARACTER(*), INTENT(  OUT)       :: OutputArray(:)                             !< Character array being read (calling routine dimensions it to max allowable size).
    CHARACTER(*), INTENT(IN   )       :: FileName                                   !< Name of the input file.
    CHARACTER(*), INTENT(IN   )       :: VariableDescribtion                        !< Text string describing the variable.
    CHARACTER(*), INTENT(IN   )       :: VariableName                               !< Text string containing the variable name.

    ! Local variables
    INTEGER                           :: MaxOutputs                                  ! Maximum length of the array being read
    INTEGER                           :: NumberWords                                 ! Number of words contained on a line
    INTEGER(IntKi)                    :: TmpErrStat                                  !< Temporary error status
    CHARACTER(ErrMsgLen)              :: TmpErrMsg                                   !< temporary error message
    CHARACTER(1000)                   :: OutLine                                     ! Character string read from file, containing output list
    CHARACTER(3)                      :: EndOfFile

    ! Initialization
    ErrStat = ErrID_None
    ErrMsg  = ''
    MaxOutputs  = SIZE(OutputArray)
    ReadNumberOutputs = 0
    OutputArray = ''

    ! Read in all of the lines containing output parameters and store them in OutputArray(:).
    ! The end of this list is specified with the line beginning with END.
    DO
    CALL LidarSim_SkipComments(TemporaryFileUnit, UnitInput, TmpErrStat, TmpErrMsg, UnitEcho)
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    IF (ErrStat >= AbortErrLev) THEN
        RETURN
    END IF
    CALL ReadVar ( UnitInput, FileName, OutLine, VariableName, VariableDescribtion, ErrStat, ErrMsg )
    IF ( ErrStat >= AbortErrLev ) RETURN

    EndOfFile = OutLine(1:3)            ! EndOfFile is the 1st 3 characters of OutLine
    CALL Conv2UC( EndOfFile )           ! Convert EndOfFile to upper case
    IF ( EndOfFile == 'END' )  EXIT     ! End of OutList has been reached; therefore, exit this DO

    NumberWords = CountWords( OutLine ) ! The number of words in OutLine.

    ReadNumberOutputs = ReadNumberOutputs + NumberWords  ! The total number of output channels read in so far.

    ! Check to see if the maximum # allowable in the array has been reached.
    IF ( ReadNumberOutputs > MaxOutputs )  THEN

    ErrStat = ErrID_Fatal
    ErrMsg = 'ReadOutputList:The maximum number of output channels allowed is '//TRIM( Int2LStr(MaxOutputs) )//'.'
    RETURN

    ELSE

    CALL GetWords ( OutLine, OutputArray((ReadNumberOutputs - NumberWords + 1):ReadNumberOutputs), NumberWords )

    END IF
    END DO

    RETURN
	
    END SUBROUTINE LidarSim_ReadOutputList
    
	
!#########################################################################################################################################################################    
    
    SUBROUTINE LidarSim_SkipComments(TemporaryFileUnit, UnitInput, ErrStat, ErrMsg, UnitEcho)
	
    IMPLICIT            NONE
    CHARACTER(*),       PARAMETER                   ::  RoutineName="LidarSim_SkipComments"

    INTEGER(IntKi),     INTENT(IN   )               ::  TemporaryFileUnit   !Unit number to look ahead for comments in the input file
    INTEGER(IntKi),     INTENT(IN   )               ::  UnitInput           !Unit number of the "normal" input file
    INTEGER(IntKi),     INTENT(  OUT)               ::  ErrStat             !< Error status of the operation
    CHARACTER(*),       INTENT(  OUT)               ::  ErrMsg              !< Error message if ErrStat /= ErrID_None
    INTEGER(IntKi),     INTENT(IN   ), OPTIONAL     ::  UnitEcho            !< The local unit number for this module's echo file
	
    ! Local variables
    INTEGER(IntKi)                                  ::  ErrStatIO           !Error Status of the read commands
    CHARACTER(1024)                                 ::  TemporaryRead       !string to read a line in
    LOGICAL                                         ::  Commented           ! true if line is commented, false otherwise
    
	! Initialization
    ErrStat = 0
    ErrMsg = ''
    
    READ(TemporaryFileUnit,*, IOSTAT = ErrStatIO) TemporaryRead
    IF(ErrStatIO > 0) THEN
        CALL SetErrStat(ErrID_Fatal,'Error checking for comments in the temporary input file',ErrStat,ErrMsg,RoutineName)
        return
    ENDIF
    
    IF ( PRESENT(UnitEcho) )  THEN
        IF ( UnitEcho > 0 ) &
        WRITE (UnitEcho,'(A)')  TRIM(TemporaryRead) !Writes read line to Echo file
    END IF
    
    IF(TemporaryRead(1:1) == '!') THEN
        Commented = .TRUE.
    ELSE
        Commented = .FALSE.
    ENDIF
    
    DO while( Commented == .TRUE. )
        READ(UnitInput,*,IOSTAT = ErrStatIO)    !Skip commented line in unit Input
        IF(ErrStatIO > 0) THEN
            CALL SetErrStat(ErrID_Fatal,'Error checking for comments in the original input file',ErrStat,ErrMsg,RoutineName)
            return
        ENDIF
        READ(TemporaryFileUnit,*, IOSTAT = ErrStatIO) TemporaryRead !Checks if next line is commented again
        IF(ErrStatIO > 0) THEN
            CALL SetErrStat(ErrID_Fatal,'Error checking for comments in the temporary input file',ErrStat,ErrMsg,RoutineName)
            return
        ENDIF
        
        IF ( PRESENT(UnitEcho) )  THEN
            IF ( UnitEcho > 0 ) &
            WRITE (UnitEcho,'(A)')  TRIM(TemporaryRead) !Writes read line to Echo file
        END IF
        
        IF(TemporaryRead(1:1) == '!') THEN
            Commented = .TRUE.
        ELSE
            Commented = .FALSE.
        ENDIF
    END DO
        
    END SUBROUTINE
    
	
!#########################################################################################################################################################################    
    
    SUBROUTINE LidarSim_CreateRotationMatrix(Roll_N, Pitch_N, Yaw_N, LidarOrientation_N)
	
    IMPLICIT         NONE
	 CHARACTER(*),    PARAMETER       ::  RoutineName="LidarSim_CreateRotationMatrix"
	
    REAL(ReKi), 	   INTENT(IN   )   ::  Roll_N                      !Roll Rotation
    REAL(ReKi), 	   INTENT(IN   )   ::  Pitch_N                     !Pitch Rotation
    REAL(ReKi), 	   INTENT(IN   )   ::  Yaw_N                       !Yaw Rotation
    REAL(ReKi), 	   INTENT(INOUT)   ::  LidarOrientation_N(3,3)     !Output Rotation matrix
    
    ! Local variables
    REAL(ReKi)                       ::  Rotations(3,3,3)            !Temporary Rotation matrices
    
    ! Roll Rotation
    Rotations(1,1,1) = 1
    Rotations(1,2,1) = 0
    Rotations(1,3,1) = 0
    
    Rotations(2,1,1) = 0
    Rotations(2,2,1) = COS(Roll_N)
    Rotations(2,3,1) = SIN(Roll_N)
    
    Rotations(3,1,1) = 0
    Rotations(3,2,1) = - SIN(Roll_N)
    Rotations(3,3,1) =   COS(Roll_N)
    
    ! Pitch Rotation
    Rotations(1,1,2) =   COS(Pitch_N)
    Rotations(1,2,2) = 0
    Rotations(1,3,2) = - SIN(Pitch_N)
    
    Rotations(2,1,2) = 0
    Rotations(2,2,2) = 1
    Rotations(2,3,2) = 0
    
    Rotations(3,1,2) = SIN(Pitch_N)
    Rotations(3,2,2) = 0
    Rotations(3,3,2) = COS(Pitch_N)
    
    ! Yaw Rotation
    Rotations(1,1,3) = COS(Yaw_N)
    Rotations(1,2,3) = SIN(Yaw_N)
    Rotations(1,3,3) = 0
    
    Rotations(2,1,3) = - SIN(Yaw_N)
    Rotations(2,2,3) =   COS(Yaw_N)
    Rotations(2,3,3) = 0
    
    Rotations(3,1,3) = 0
    Rotations(3,2,3) = 0
    Rotations(3,3,3) = 1
    
    ! Combining rotations
    LidarOrientation_N = MATMUL( MATMUL( Rotations(:,:,3),Rotations(:,:,2) ), Rotations(:,:,1) )
    
    END SUBROUTINE LidarSim_CreateRotationMatrix
    
	
!#########################################################################################################################################################################
    
    SUBROUTINE LidarSim_InitMeasuringPoints_Cartesian(p, InputFileData, ErrStat, ErrMsg)
	
    IMPLICIT                            NONE
    CHARACTER(*),                       PARAMETER       ::  RoutineName="LidarSim_InitMeasuringPoints_Cartesian"
	
    TYPE(LidarSim_ParameterType),       INTENT(INOUT)   ::  p                   !parameter data (destination of the InputFileData)
    TYPE(LidarSim_InputFile),           INTENT(IN   )   ::  InputFileData       !data read from the input file
    INTEGER(IntKi),                     INTENT(  OUT)   ::  ErrStat             !< Error status of the operation
    CHARACTER(*),                       INTENT(  OUT)   ::  ErrMsg              !< Error message if ErrStat /= ErrID_None
	
    ! Local variables
    INTEGER(IntKi)                                      ::  LoopCounter         !< counter to run through all cartesian coordinates data
    INTEGER(IntKi)                                      ::  TmpErrStat          !< Temporary error status
    CHARACTER(ErrMsgLen)                                ::  TmpErrMsg           !< temporary error message
    
	 ! Initialization
    ErrStat        =  0
    ErrMsg         =  ""
    
    CALL AllocAry( p%MeasuringPoints_L, 3, SIZE(InputFileData%X_Cartesian_L), 'MeasuringPoints_L', TmpErrStat, TmpErrMsg )     !Allocate the array size for n=CounterChannelNumbers measuringpositions
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    CALL AllocAry( p%MeasuringPoints_Spherical_L, 3,  SIZE(InputFileData%X_Cartesian_L), 'MeasuringPoints_Spherical_L', TmpErrStat, TmpErrMsg )
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    
    DO LoopCounter = 1,SIZE(InputFileData%X_Cartesian_L)
        p%MeasuringPoints_L(1,LoopCounter) = InputFileData%X_Cartesian_L(LoopCounter)
        p%MeasuringPoints_L(2,LoopCounter) = InputFileData%Y_Cartesian_L(LoopCounter)
        p%MeasuringPoints_L(3,LoopCounter) = InputFileData%Z_Cartesian_L(LoopCounter)
        p%MeasuringPoints_Spherical_L(:,LoopCounter) = LidarSim_Cartesian2Spherical(InputFileData%X_Cartesian_L(LoopCounter),InputFileData%Y_Cartesian_L(LoopCounter),InputFileData%Z_Cartesian_L(LoopCounter))
    END DO
	
    END SUBROUTINE LidarSim_InitMeasuringPoints_Cartesian
   
   
!#########################################################################################################################################################################
    
    SUBROUTINE LidarSim_InitMeasuringPoints_Spherical(p, InputFileData, ErrStat, ErrMsg)
	
    IMPLICIT                            NONE
    CHARACTER(*),                       PARAMETER       ::  RoutineName="LidarSim_InitMeasuringPoints_Spherical"

    TYPE(LidarSim_ParameterType),       INTENT(INOUT)   ::  p                       !parameter data (destination of the InputFileData)
    TYPE(LidarSim_InputFile),           INTENT(IN   )   ::  InputFileData           !data read from the input file
    INTEGER(IntKi),                     INTENT(  OUT)   ::  ErrStat                 !< Error status of the operation
    CHARACTER(*),                       INTENT(  OUT)   ::  ErrMsg                  !< Error message if ErrStat /= ErrID_None
    
    ! Local variables
    INTEGER(IntKi)                                      ::  OuterLoopCounter        !counter for looping through the coordinate data
    INTEGER(IntKi)                                      ::  InnerLoopCounter        !counter for looping through the multiple range gates
    INTEGER(IntKi)                                      ::  CounterChannelNumbers   !counts the amount of channels
    INTEGER(IntKi)                                      ::  TmpErrStat              !< Temporary error status
    CHARACTER(ErrMsgLen)                                ::  TmpErrMsg               !< temporary error message

	 ! Initialization
    ErrStat        =  0
    ErrMsg         =  ""
    
    CALL AllocAry( p%MeasuringPoints_L, 3,InputFileData%NumberOfPoints_Spherical*InputFileData%GatesPerBeam, 'MeasuringPoints_L', TmpErrStat, TmpErrMsg )     !Allocate the array size for n=CounterChannelNumbers measuringpositions
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    CALL AllocAry( p%MeasuringPoints_Spherical_L, 3,InputFileData%NumberOfPoints_Spherical*InputFileData%GatesPerBeam, 'MeasuringPoints_Spherical_L', TmpErrStat, TmpErrMsg )  
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)

    OuterLoopCounter = 1
    InnerLoopCounter = 1
    CounterChannelNumbers = 1    
        
    DO WHILE( OuterLoopCounter <= InputFileData%NumberOfPoints_Spherical)
        DO WHILE( InnerLoopCounter <= InputFileData%GatesPerBeam)
                IF ( InputFileData%Range(OuterLoopCounter,InnerLoopCounter) /= 0 )THEN  !Range gates mustn't be 0. => Divide by 0 !
                    p%MeasuringPoints_L(:,CounterChannelNumbers) = &   !Transformation from the spherical to cartesian coordinates
                        LidarSim_Spherical2Cartesian(InputFileData%Azimuth(OuterLoopCounter),InputFileData%Elevation(OuterLoopCounter),InputFileData%Range(OuterLoopCounter,InnerLoopCounter))
                    p%MeasuringPoints_Spherical_L(:,CounterChannelNumbers) = &
                        (/ InputFileData%Range(OuterLoopCounter,InnerLoopCounter),InputFileData%Azimuth(OuterLoopCounter),InputFileData%Elevation(OuterLoopCounter)/)
                    CounterChannelNumbers = CounterChannelNumbers + 1
                ELSE
                    CALL SetErrStat(ErrID_Fatal,"Range gates must not be 0",ErrStat,ErrMsg,RoutineName)
                ENDIF
            InnerLoopCounter = InnerLoopCounter + 1
        END DO
        InnerLoopCounter = 1
        OuterLoopCounter = OuterLoopCounter + 1
    END DO
	
    END SUBROUTINE LidarSim_InitMeasuringPoints_Spherical

	
!#########################################################################################################################################################################
    
    FUNCTION LidarSim_Spherical2Cartesian(Azimuth, Elevation, Range)
	
    IMPLICIT        NONE
	 CHARACTER(*),   PARAMETER       ::  RoutineName="LidarSim_Spherical2Cartesian"
	
    REAL(ReKi),     INTENT(IN   )   ::  Azimuth                             !Azimuth angle
    REAL(ReKi),     INTENT(IN   )   ::  Elevation                           !Elevation angle
    REAL(ReKi),     INTENT(IN   )   ::  Range                               !range gate
    REAL(ReKi),     DIMENSION (3)   ::  LidarSim_Spherical2Cartesian        !Output : x,y,z coordinates
    
    LidarSim_Spherical2Cartesian(1)  =   Range*COS(Elevation)*COS(Azimuth)   !x
    LidarSim_Spherical2Cartesian(2)  =   Range*COS(Elevation)*SIN(Azimuth)   !y
    LidarSim_Spherical2Cartesian(3)  =   Range*SIN(Elevation)                !z
	
    END FUNCTION LidarSim_Spherical2Cartesian
    
	
!#########################################################################################################################################################################    
    
    FUNCTION LidarSim_Cartesian2Spherical(X, Y, Z)
	
    IMPLICIT        NONE
	 CHARACTER(*),   PARAMETER       ::  RoutineName="LidarSim_Cartesian2Spherical"
	
    REAL(ReKi),     INTENT(IN   )   ::  X                             !Azimuth angle
    REAL(ReKi),     INTENT(IN   )   ::  Y                           !Elevation angle
    REAL(ReKi),     INTENT(IN   )   ::  Z                               !range gate
    REAL(ReKi),     DIMENSION (3)   ::  LidarSim_Cartesian2Spherical       !Output : x,y,z coordinates

    LidarSim_Cartesian2Spherical(1)  =   SQRT(X**2+Y**2+Z**2)   !range
    
    IF(LidarSim_Cartesian2Spherical(1) > 0 ) THEN
        LidarSim_Cartesian2Spherical(3)  =   ASIN(Z/LidarSim_Cartesian2Spherical(1))   !y
        
        LidarSim_Cartesian2Spherical(2) = ATAN2(Y,X)
    ELSE
        LidarSim_Cartesian2Spherical(2) = 0
        LidarSim_Cartesian2Spherical(3) = 0
    ENDIF
	
    END FUNCTION LidarSim_Cartesian2Spherical
    
	
!#########################################################################################################################################################################
    
    FUNCTION LidarSim_TransformLidarToInertial(NacelleMotion, p, MeasuringPoint_L)
	
    IMPLICIT        NONE
	 CHARACTER(*),   PARAMETER       	 ::  RoutineName="LidarSim_TransformLidarToInertial"
	
    REAL(ReKi)                          ::  LidarSim_TransformLidarToInertial(3)    !Output calculated transformation from the lidar coord. sys. to the inertial system
    TYPE(MeshType)                      ::  NacelleMotion                           !Data describing the motion of the nacelle coord. sys.
    TYPE(LidarSim_ParameterType)        ::  p                                       !Parameter data 
    REAL(ReKi)                          ::  MeasuringPoint_L(3)                     !point which needs to be transformed
    
    ! local variables
    REAL(ReKi)                          :: PositionNacelle_I(3)                     !local variable to save the current Nacelle position (in the inerital cord. sys.)
    
    PositionNacelle_I = NacelleMotion%Position(:,1) + NacelleMotion%TranslationDisp(:,1)
       
    LidarSim_TransformLidarToInertial = PositionNacelle_I +  MATMUL(TRANSPOSE(NacelleMotion%Orientation(:,:,1)),(p%LidarPosition_N + MATMUL( p%LidarOrientation_N,MeasuringPoint_L ) ) )
  
    END FUNCTION LidarSim_TransformLidarToInertial
    
	
!#########################################################################################################################################################################
    
    SUBROUTINE LidarSim_InitializeWeightingManual(p, InputFileData, ErrStat, ErrMsg)
    
    IMPLICIT                        NONE
    CHARACTER(*),                   PARAMETER       ::  RoutineName="LidarSim_InitializeWeightingManual"
    
    TYPE(LidarSim_ParameterType),   INTENT(INOUT)   ::  p                   ! parameter data to write results in
    TYPE(LidarSim_InputFile),       INTENT(IN   )   ::  InputFileData       ! Inputdata from the input file
    INTEGER(IntKi),                 INTENT(  OUT)   ::  ErrStat             !< Temporary error status
    CHARACTER(*),                   INTENT(  OUT)   ::  ErrMsg              !< temporary error message
    
    ! local variables
    INTEGER(IntKi)          ::  TmpErrStat
    CHARACTER(ErrMsgLen)    ::  TmpErrMsg           !< temporary error message
    
    TmpErrStat = 0
    TmpErrMsg = ''

    CALL AllocAry( p%WeightingDistance,SIZE(InputFileData%ManualWeightingDistance), 'p%WeightingDistance', TmpErrStat, TmpErrMsg )  !Allocating the needed size for the weighting distance vector
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    CALL AllocAry( p%Weighting,SIZE(InputFileData%ManualWeighting), 'p%Weighting', TmpErrStat, TmpErrMsg )                          !Allocating the needed size for the weighting vector
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    p%WeightingDistance = InputFileData%ManualWeightingDistance                                                                     !writing the input distances in the parameter
    p%Weighting(:) = InputFileData%ManualWeighting(:) / SUM(InputFileData%ManualWeighting)                                          !writing the input weighting in the parameter and normalizing it (sum = 1)
    
    END SUBROUTINE LidarSim_InitializeWeightingManual
    
    
!#########################################################################################################################################################################    

    SUBROUTINE LidarSim_InitializeWeightingGauss(p, InputFileData, ErrStat, ErrMsg)
    
    IMPLICIT                        NONE
    CHARACTER(*),                   PARAMETER       ::  RoutineName="LidarSim_InitializeWeightingGauss"
    
    TYPE(LidarSim_ParameterType),   INTENT(INOUT)   ::  p                   ! parameter data to write results in
    TYPE(LidarSim_InputFile),       INTENT(IN   )   ::  InputFileData       ! Inputdata from the input file
    INTEGER(IntKi),                 INTENT(  OUT)   ::  ErrStat             !< Error status of the operation
    CHARACTER(*),                   INTENT(  OUT)   ::  ErrMsg              !< Error message if ErrStat /= ErrID_None
    
    ! local variables
    INTEGER(IntKi)          ::  Counter                                     !Loopcounter for every point to evaluate
    REAL(ReKi)              ::  Dist                                        !Distance between each evaluation point
    INTEGER(IntKi)          ::  TmpErrStat                                  !< Temporary error status
    CHARACTER(ErrMsgLen)    ::  TmpErrMsg                                   !< temporary error message
    
    ErrStat =   0
    ErrMsg  =   ''
    Dist = 2*InputFileData%FWHM/(InputFileData%PointsToEvaluate+1)          !Distance between each weighting point
    
    CALL AllocAry( p%WeightingDistance,InputFileData%PointsToEvaluate, 'p%WeightingDistance', TmpErrStat, TmpErrMsg )   !Allocating the needed size for the weighting distance vector
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    CALL AllocAry( p%Weighting,InputFileData%PointsToEvaluate, 'p%Weighting', TmpErrStat, TmpErrMsg )                   !Allocating the needed size for the weighting vector
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    
    DO Counter=1,InputFileData%PointsToEvaluate
        p%WeightingDistance(Counter) = (Counter) * Dist + (-InputFileData%FWHM)             !Creating the distance vector
        p%Weighting(Counter) = ( (2*SQRT(LOG(2.0)))/(InputFileData%FWHM*SQRT(Pi_D)) ) *&      !Calculation of the gaussian distribution
        EXP( -((p%WeightingDistance(Counter)**2)*4*LOG(2.0))/(InputFileData%FWHM**2) ) !&
    END DO
    p%Weighting = p%Weighting / SUM( p%Weighting )

    END SUBROUTINE LidarSim_InitializeWeightingGauss
    
    
!#########################################################################################################################################################################   
    
    SUBROUTINE LidarSim_CalculateVlos(p, UnitVector_I, Vlos, MeasuringPosition_I, LidarPosition_I,&
    Time, IfW_p, IfW_ContStates, IfW_DiscStates, IfW_ConstrStates, IfW_OtherStates, IfW_m, ErrStat, ErrMsg)
    
    IMPLICIT                                NONE
    CHARACTER(*),                           PARAMETER       ::  RoutineName="LidarSim_CalculateVlos"
    
    TYPE(LidarSim_ParameterType),           INTENT(INOUT)   ::  p                           !parameter data of the lidar module
    REAL(ReKi),                             INTENT(IN   )   ::  UnitVector_I(3)             !Line of Sight Unit Vector
    REAL(ReKi),                             INTENT(INOUT)   ::  MeasuringPosition_I(3)      !Position of the measuring point
    REAL(ReKi),                             INTENT(IN   )   ::  LidarPosition_I(3)      !Position of the measuring point
    REAL(ReKi),                             INTENT(  OUT)   ::  Vlos                        !Calculated speed in los direction
    REAL(DbKi),                             INTENT(IN   )   ::  Time                        !< Current simulation time in seconds

    !IfW Parameter
    TYPE(InflowWind_ParameterType),         INTENT(IN   )   ::  IfW_p                       !< Parameters
    TYPE(InflowWind_ContinuousStateType),   INTENT(IN   )   ::  IfW_ContStates              !< Continuous states at Time
    TYPE(InflowWind_DiscreteStateType),     INTENT(IN   )   ::  IfW_DiscStates              !< Discrete states at Time
    TYPE(InflowWind_ConstraintStateType),   INTENT(IN   )   ::  IfW_ConstrStates            !< Constraint states at Time
    TYPE(InflowWind_OtherStateType),        INTENT(IN   )   ::  IfW_OtherStates             !< Other/optimization states at Time
    TYPE(InflowWind_MiscVarType),           INTENT(INOUT)   ::  IfW_m                       !< Misc variables for optimization (not copied in glue code)
    
    !Error Variables
    INTEGER(IntKi),                         INTENT(  OUT)   ::  ErrStat                     !< Error status of the operation
    CHARACTER(*),                           INTENT(  OUT)   ::  ErrMsg                      !< Error message if ErrStat /= ErrID_None
    
    !Local Variables
    TYPE(InflowWind_InputType)              ::  InputForCalculation                         ! input data field for the calculation in the InflowWind module
    TYPE(InflowWind_OutputType)             ::  OutputForCalculation                        ! data field were the calculated speed is written from the InflowWind module
    INTEGER(IntKi)                          ::  Counter                                     ! Counter for the loop for the different weightings of the point
    REAL(ReKi),DIMENSION(:), ALLOCATABLE    ::  Vlos_tmp                                    !< Array with all temporary Vlos
    
    ! Temporary variables for error handling
    INTEGER(IntKi)                                          ::  ErrStat2        
    CHARACTER(ErrMsgLen)                                    ::  ErrMsg2

    !Initialize error values
    ErrStat        =  0
    ErrMsg         =  ""
    
    CALL AllocAry(InputForCalculation%PositionXYZ, 3,1, 'InputForCalculation%PositionXYZ',ErrStat2, ErrMsg2)        !Allocating needed space for the input
    CALL SetErrStat(ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
    CALL AllocAry(OutputForCalculation%VelocityUVW, 3,1, 'OutputForCalculation%VelocityUVW',ErrStat2, ErrMsg2)      !Allocating needed space for the output
    CALL SetErrStat(ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
    CALL AllocAry(Vlos_tmp ,SIZE(p%Weighting), 'Vlos_tmp%VelocityUVW',ErrStat2, ErrMsg2)                            !Allocating space for temporary windspeeds
    CALL SetErrStat(ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
     
    IF(IfW_p%WindType == 1 .OR. IfW_p%WindType == 2)Then !Uniform Wind 2 (und steady 1)
        MeasuringPosition_I(1) = MeasuringPosition_I(1)-LidarPosition_I(1)  !In the uniform wind case. the wind hits the turbine at the same time indepentend of the x shift
        DO Counter = 1, SIZE(p%Weighting)
            InputForCalculation%PositionXYZ(:,1) = MeasuringPosition_I + p%WeightingDistance(Counter) * UnitVector_I                                                    !position of the weighted measuring point
            CALL CalculateOutput(Time + DBLE(-InputForCalculation%PositionXYZ(1,1)/p%Uref),&                                                                            !X vector to timeshift! X/Uref
            InputForCalculation, IfW_p, IfW_ContStates, IfW_DiscStates, IfW_ConstrStates, IfW_OtherStates, OutputForCalculation, IfW_m, .FALSE., ErrStat2, ErrMsg2 )    !Calculation of the windspeed
            Vlos_tmp(Counter) = - DOT_PRODUCT(OutputForCalculation%VelocityUVW(:,1),UnitVector_I)
        END DO
    ELSE IF(IfW_p%WindType ==  3 .OR. IfW_p%WindType == 4) THEN        !Bladed Turublent 4 ( und TurbSim 3)
        DO Counter = 1, SIZE(p%Weighting)
            
            InputForCalculation%PositionXYZ(:,1) = MeasuringPosition_I + p%WeightingDistance(Counter) * UnitVector_I                                                    !position of the weighted measuring point
            CALL CalculateOutput(Time,&                                                                            !X vector to timeshift! X/Uref
            InputForCalculation, IfW_p, IfW_ContStates, IfW_DiscStates, IfW_ConstrStates, IfW_OtherStates, OutputForCalculation, IfW_m, .FALSE., ErrStat2, ErrMsg2 )    !Calculation of the windspeed
            Vlos_tmp(Counter) = - DOT_PRODUCT(OutputForCalculation%VelocityUVW(:,1),UnitVector_I)
        END DO
    END IF
    Vlos = DOT_PRODUCT(Vlos_tmp, p%Weighting)           !Calculation of the weighted windspeed

    DEALLOCATE (InputForCalculation%PositionXYZ)        !Free Input Positions for the next measurement
    DEALLOCATE (OutputForCalculation%VelocityUVW)       !Free Ouput Positions for the next measurement
    DEALLOCATE (Vlos_tmp)

    END SUBROUTINE LidarSim_CalculateVlos
    
    
!#########################################################################################################################################################################       
    
    SUBROUTINE LidarSim_CalculateIMU(p,y,u)
    
    IMPLICIT                                   NONE
    CHARACTER(*),                              PARAMETER            ::  RoutineName="LidarSim_LidarSim_CalculateIMU"
    
    TYPE(LidarSim_ParameterType),              INTENT(INOUT)        ::  p
    TYPE(LidarSim_OutputType),                 INTENT(INOUT)        ::  y                       !Outputs computed at Time (IN for mesh reasons and data allocation)
    TYPE(LidarSim_InputType),                  INTENT(IN   )        ::  u   
    
    ! local variables
    REAL(ReKi)                                                      ::  CrossProduct(3)         !Variable for the crossproduct of the rotation and the lidar position ( in the nacelle coord. system)
    REAL(ReKi)                                                      ::  Rotation_L_I(3,3)
    REAL(ReKi)                                                      ::  Roll
    REAL(ReKi)                                                      ::  Pitch
    REAL(ReKi)                                                      ::  Yaw
    REAL(ReKi)                                                      ::  DisplacementNacelle(3)
    REAL(ReKi)                                                      ::  DisplacementLidar(3)
    REAL(ReKi)                                                      ::  LidarPosition_I(3)
    
    Rotation_L_I = MATMUL(TRANSPOSE(u%NacelleMotion%Orientation(:,:,1)),p%LidarOrientation_N)
    IF(.NOT.(Rotation_L_I(3,1) == 1 .OR. Rotation_L_I(3,1) == -1)) THEN
        Pitch = -ASIN(Rotation_L_I(3,1))
        Roll = ATAN2(Rotation_L_I(3,2)/cos(Pitch),Rotation_L_I(3,3)/cos(Pitch))
        Yaw = ATAN2(Rotation_L_I(2,1)/cos(Pitch), Rotation_L_I(1,1)/cos(Pitch))  
    ELSE
        Yaw = 0
        IF(Rotation_L_I(3,1) == 1) THEN
            Pitch = PiBy2_D
            Roll = Yaw + ATAN2(Rotation_L_I(1,2),Rotation_L_I(1,3))
        ELSE
            Pitch = -PiBy2_D
            Roll = -Yaw + ATAN2(-Rotation_L_I(1,2),-Rotation_L_I(1,3))
        END IF
    END IF
    
    LidarPosition_I = MATMUL(TRANSPOSE(u%NacelleMotion%Orientation(:,:,1)),p%LidarPosition_N) !Rotates the position vector to the orientation of the inertial coord. system
    
    y%IMUOutputs(1)     = Roll                              !Roll Angle
    y%IMUOutputs(2)     = u%NacelleMotion%RotationVel(1,1)  !Roll Angle Velocity
    y%IMUOutputs(3)     = u%NacelleMotion%RotationAcc(1,1)  !Roll Angle Acceleration
    y%IMUOutputs(4)     = Pitch                             !Pitch Angle
    y%IMUOutputs(5)     = u%NacelleMotion%RotationVel(2,1)  !Pitch Angle Velocity
    y%IMUOutputs(6)     = u%NacelleMotion%RotationAcc(2,1)  !Pitch Angle Acceleration
    y%IMUOutputs(7)     = Yaw                               !Yaw Angle
    y%IMUOutputs(8)     = u%NacelleMotion%RotationVel(3,1)  !Yaw Angle Velocity
    y%IMUOutputs(9)     = u%NacelleMotion%RotationAcc(3,1)  !Yaw Angle Acceleration
    
    y%IMUOutputs(10)    = u%NacelleMotion%TranslationDisp(1,1)  !Displacement x 
    y%IMUOutputs(13)    = u%NacelleMotion%TranslationDisp(2,1)  !Displacement y
    y%IMUOutputs(16)    = u%NacelleMotion%TranslationDisp(3,1)  !Displacement z
    
    DisplacementNacelle(1) = u%NacelleMotion%TranslationDisp(1,1)
    DisplacementNacelle(2) = u%NacelleMotion%TranslationDisp(2,1)
    DisplacementNacelle(3) = u%NacelleMotion%TranslationDisp(3,1)
    
    DisplacementLidar   = LidarPosition_I + DisplacementNacelle
    
    y%IMUOutputs(10)    = DisplacementLidar(1)
    y%IMUOutputs(13)    = DisplacementLidar(2)
    y%IMUOutputs(16)    = DisplacementLidar(3)
    
    CrossProduct(1)     = u%NacelleMotion%RotationVel(2,1)*LidarPosition_I(3) - u%NacelleMotion%RotationVel(3,1)*LidarPosition_I(2)
    CrossProduct(2)     = u%NacelleMotion%RotationVel(3,1)*LidarPosition_I(1) - u%NacelleMotion%RotationVel(1,1)*LidarPosition_I(3)
    CrossProduct(3)     = u%NacelleMotion%RotationVel(1,1)*LidarPosition_I(2) - u%NacelleMotion%RotationVel(2,1)*LidarPosition_I(1)
    
    y%IMUOutputs(11)    = u%NacelleMotion%TranslationVel(1,1) + CrossProduct(1)    !Velocity x
    y%IMUOutputs(14)    = u%NacelleMotion%TranslationVel(2,1) + CrossProduct(2)    !Velocity y
    y%IMUOutputs(17)    = u%NacelleMotion%TranslationVel(3,1) + CrossProduct(3)    !Velocity z
    
    CrossProduct(1)     = u%NacelleMotion%RotationAcc(2,1)*LidarPosition_I(3) - u%NacelleMotion%RotationAcc(3,1)*LidarPosition_I(2)
    CrossProduct(2)     = u%NacelleMotion%RotationAcc(3,1)*LidarPosition_I(1) - u%NacelleMotion%RotationAcc(1,1)*LidarPosition_I(3)
    CrossProduct(3)     = u%NacelleMotion%RotationAcc(1,1)*LidarPosition_I(2) - u%NacelleMotion%RotationAcc(2,1)*LidarPosition_I(1)    
    
    y%IMUOutputs(12)    = u%NacelleMotion%TranslationAcc(1,1) + CrossProduct(1)     !Acceleration x
    y%IMUOutputs(15)    = u%NacelleMotion%TranslationAcc(2,1) + CrossProduct(2)     !Acceleration y
    y%IMUOutputs(18)    = u%NacelleMotion%TranslationAcc(3,1) + CrossProduct(3)     !Acceleration z

    END SUBROUTINE
    
    
!#########################################################################################################################################################################       
    
    SUBROUTINE LidarSim_InitializeOutputs(y,p, InitOutData, InputFileData, ErrStat, ErrMsg)
    
    IMPLICIT                               NONE
    CHARACTER(*),                          PARAMETER       ::  RoutineName='LidarSim_InitializeOutputs'
    
    TYPE(LidarSim_OutputType),             INTENT(  OUT)   ::  y                   ! Parameter for lidar outputs
    TYPE(LidarSim_ParameterType),          INTENT(INOUT)   ::  p                   ! Parameter data for the lidar module
    TYPE(LidarSim_InitOutputType),         INTENT(  OUT)   ::  InitOutData
    TYPE(LidarSim_InputFile),              INTENT(IN   )   ::  InputFileData
    INTEGER(IntKi),                        INTENT(  OUT)   ::  ErrStat              !< Temporary error status
    CHARACTER(ErrMsgLen),                  INTENT(  OUT)   ::  ErrMsg               !< temporary error message
    
    !Local error variables
    INTEGER(IntKi)          ::  TmpErrStat
    CHARACTER(ErrMsgLen)    ::  TmpErrMsg           !< temporary error message
    
    !Local variables
    INTEGER(IntKi)                          ::  SizeOutput
    INTEGER(IntKi)                          ::  LoopCounter
    INTEGER(IntKi)                          ::  NumberValidOutputs
    INTEGER(IntKi),DIMENSION(:),ALLOCATABLE ::  ValidOutputs
    CHARACTER(15) ,DIMENSION(:),ALLOCATABLE ::  ValidOutputNames
    CHARACTER(1024)                         ::  TmpIntegerToString
    CHARACTER(15)                           ::  OutListTmp
    
    INTEGER(IntKi), PARAMETER               ::  ROLLLI      =   1
    INTEGER(IntKi), PARAMETER               ::  ROLLDTLI    =   2
    INTEGER(IntKi), PARAMETER               ::  ROLLDTDTLI  =   3
    INTEGER(IntKi), PARAMETER               ::  PTCHLI      =   4
    INTEGER(IntKi), PARAMETER               ::  PTCHDTLI    =   5
    INTEGER(IntKi), PARAMETER               ::  PTCHDTDTLI  =   6
    INTEGER(IntKi), PARAMETER               ::  YAWLI       =   7
    INTEGER(IntKi), PARAMETER               ::  YAWDTLI     =   8
    INTEGER(IntKi), PARAMETER               ::  YAWDTDTLI   =   9
    INTEGER(IntKi), PARAMETER               ::  XLI         =   10
    INTEGER(IntKi), PARAMETER               ::  XDTLI       =   11
    INTEGER(IntKi), PARAMETER               ::  XDTDTLI     =   12
    INTEGER(IntKi), PARAMETER               ::  YLI         =   13
    INTEGER(IntKi), PARAMETER               ::  YDTLI       =   14
    INTEGER(IntKi), PARAMETER               ::  YDTDTLI     =   15
    INTEGER(IntKi), PARAMETER               ::  ZLI         =   16
    INTEGER(IntKi), PARAMETER               ::  ZDTLI       =   17
    INTEGER(IntKi), PARAMETER               ::  ZDTDTLI     =   18
    INTEGER(IntKi), PARAMETER               ::  AZIMUTHLI   =   19
    INTEGER(IntKi), PARAMETER               ::  ELEVATLI    =   20
    INTEGER(IntKi), PARAMETER               ::  MEASTIMELI  =   21
    INTEGER(IntKi), PARAMETER               ::  NEWDATALI   =   22
    INTEGER(IntKi), PARAMETER               ::  BEAMIDLI    =   23
        
    CHARACTER(ChanLen), DIMENSION(:), ALLOCATABLE  :: ValidParamAry     ! This lists the names of the allowed parameters, which must be sorted alphabetically
    INTEGER(IntKi), DIMENSION(:), ALLOCATABLE  :: ParamIndexAry     ! This lists the index into AllOuts(:) of the allowed parameters ValidParamAry(:)
    CHARACTER(ChanLen), DIMENSION(:), ALLOCATABLE  :: ParamUnitsAry     ! This lists the units corresponding to the allowed parameters
    
    !Error Variables
    TmpErrStat  = 0
    TmpErrMsg   = ''
    
    SizeOutput = InputFileData%GatesPerBeam
        
    CALL AllocAry( ValidParamAry, 23+(2*SizeOutput), 'ValidParamAry', TmpErrStat, TmpErrMsg )
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    CALL AllocAry( ParamIndexAry, 23+(2*SizeOutput), 'ParamIndexAry', TmpErrStat, TmpErrMsg )
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    CALL AllocAry( ParamUnitsAry, 23+(2*SizeOutput), 'ParamUnitsAry', TmpErrStat, TmpErrMsg )
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    
    ! Fill ValidParamAry and ParamIndexAry in alphabetical order
    ValidParamAry( 1 : 8 ) = (/ & 
        "AZIMUTHLI" ,"BEAMIDLI"  ,"ELEVATLI"  ,"MEASTIMELI","NEWDATALI" ,"PTCHDTDTLI", & 
        "PTCHDTLI"  ,"PTCHLI"    /)
    ParamIndexAry( 1 : 8 ) = (/ & 
        AZIMUTHLI   ,BEAMIDLI    ,ELEVATLI    ,MEASTIMELI  ,NEWDATALI   ,PTCHDTDTLI  , & 
        PTCHDTLI    ,PTCHLI      /)
    DO LoopCounter = 1,SizeOutput
        WRITE(UNIT=TmpIntegerToString,FMT='(I2.2)') LoopCounter
        ValidParamAry( 8 + LoopCounter ) = "RANGE"//TRIM(ADJUSTL(TmpIntegerToString))//"LI"
        ParamIndexAry( 8 + LoopCounter ) = 23 + LoopCounter
    ENDDO
    ValidParamAry( (9 + SizeOutput) : (11 + SizeOutput) ) = (/ & 
        "ROLLDTDTLI","ROLLDTLI"  ,"ROLLLI"    /)
    ParamIndexAry( (9 + SizeOutput) : (11 + SizeOutput) ) = (/ & 
        ROLLDTDTLI  ,ROLLDTLI    ,ROLLLI      /)
    DO LoopCounter = 1,SizeOutput
        WRITE(UNIT=TmpIntegerToString,FMT='(I2.2)') LoopCounter
        ValidParamAry( 11 + SizeOutput + LoopCounter ) = "VLOS"//TRIM(ADJUSTL(TmpIntegerToString))//"LI"
        ParamIndexAry( 11 + SizeOutput + LoopCounter ) = 23 + SizeOutput + LoopCounter
    ENDDO
    ValidParamAry( (12 + (2*SizeOutput)) : (23 + (2*SizeOutput)) ) = (/ & 
        "XDTDTLI"   ,"XDTLI"     ,"XLI"       ,"YAWDTDTLI" ,"YAWDTLI"   ,"YAWLI"     , & 
        "YDTDTLI"   ,"YDTLI"     ,"YLI"       ,"ZDTDTLI"   ,"ZDTLI"     ,"ZLI"       /)
    ParamIndexAry( (12 + (2*SizeOutput)) : (23 + (2*SizeOutput)) ) = (/ & 
        XDTDTLI     ,XDTLI       ,XLI         ,YAWDTDTLI   ,YAWDTLI     ,YAWLI       , & 
        YDTDTLI     ,YDTLI       ,YLI         ,ZDTDTLI     ,ZDTLI       ,ZLI         /)
    
    ! Fill ParamUnitsAry according to parameter order
    ParamUnitsAry( 1 : 23 ) = (/ & 
        "(rad)     ","(rad/s)   ","(rad/s^2) ","(rad)     ","(rad/s)   ","(rad/s^2) ", & 
        "(rad)     ","(rad/s)   ","(rad/s^2) ","(m)       ","(m/s)     ","(m/s^2)   ", & 
        "(m)       ","(m/s)     ","(m/s^2)   ","(m)       ","(m/s)     ","(m/s^2)   ", & 
        "(rad)     ","(rad)     ","(s)       ","()        ","()        "/)
    DO LoopCounter = 1,SizeOutput
        ParamUnitsAry( 23 + LoopCounter ) = "(m)       "
        ParamUnitsAry( 23 + SizeOutput + LoopCounter ) = "(m/s)     "
    ENDDO
    
    CALL AllocAry( y%IMUOutputs, 18, 'IMUOutputs', TmpErrStat, TmpErrMsg )                              !Allocate array for all IMU data ( rotation and position displacement, velocity, acceleration)
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    CALL AllocAry( ValidOutputs, 23+(2*SizeOutput), 'ValidOutputs', TmpErrStat, TmpErrMsg )             !Allocate the maximal additional outputchannels
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    CALL AllocAry( ValidOutputNames, 23+(2*SizeOutput), 'ValidOutputNames', TmpErrStat, TmpErrMsg )     !Allocate the maximal additional outputchannels
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    
    NumberValidOutputs=0
    DO LoopCounter = 1, InputFileData%NumOuts
        OutListTmp = InputFileData%OutList(LoopCounter)
        CALL Conv2UC(OutListTmp)
        ValidOutputs(NumberValidOutputs+1) = IndexCharAry(OutListTmp,ValidParamAry)
        IF(ValidOutputs(NumberValidOutputs+1) > 0) THEN
            ValidOutputs(NumberValidOutputs+1)      =   ParamIndexAry(ValidOutputs(NumberValidOutputs+1))
            ValidOutputNames(NumberValidOutputs+1)  =   InputFileData%OutList(LoopCounter)
            NumberValidOutputs = NumberValidOutputs + 1            
        ENDIF
    ENDDO
    
    IF(NumberValidOutputs>0) THEN
        CALL AllocAry( p%ValidOutputs, NumberValidOutputs, 'p%ValidOutputs', TmpErrStat, TmpErrMsg )                     !Allocate the fitting amount of outputchannels
        CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
        p%ValidOutputs=ValidOutputs(1:NumberValidOutputs)   
    ENDIF
    
    CALL AllocAry( y%WriteOutput, NumberValidOutputs, 'WriteOutput', TmpErrStat, TmpErrMsg )                     !Allocate the actual output array
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    CALL AllocAry( InitOutData%WriteOutputHdr, NumberValidOutputs, 'WriteOutputHdr', TmpErrStat, TmpErrMsg )     !Name of the data output channels   (Size of the WriteOutputHdr array defines the number of outputs)
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    CALL AllocAry( InitOutData%WriteOutputUnt, NumberValidOutputs, 'WriteOutputUnt', TmpErrStat, TmpErrMsg )     !units of the output channels
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    
    DO LoopCounter = 1, NumberValidOutputs
         y%WriteOutput( LoopCounter ) = 0
         InitOutData%WriteOutputHdr( LoopCounter ) = ValidOutputNames(LoopCounter)
         InitOutData%WriteOutputUnt( LoopCounter ) = ParamUnitsAry(p%ValidOutputs(LoopCounter))
    ENDDO
    
    DEALLOCATE(ValidOutputNames)
    DEALLOCATE(ValidOutputs)
    
    ! Initialize SwapOutputs array
    CALL AllocAry( y%SwapOutputs, 2+SizeOutput+6, 'SwapOutputs', TmpErrStat, TmpErrMsg )
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    
    y%SwapOutputs(1) = 0                        !NewData
    y%SwapOutputs(2) = 0                        !BeamID
    
    DO LoopCounter = 1,SizeOutput
         y%SwapOutputs(2 + LoopCounter) = 0     !Vlos
    ENDDO

    y%SwapOutputs(2 + SizeOutput + 1)   = 0     ! LdrRoll
    y%SwapOutputs(2 + SizeOutput + 2)   = 0     ! LdrPitch
    y%SwapOutputs(2 + SizeOutput + 3)   = 0     ! LdrYaw
    y%SwapOutputs(2 + SizeOutput + 4)   = 0     ! LdrXd
    y%SwapOutputs(2 + SizeOutput + 5)   = 0     ! LdrYd 
    y%SwapOutputs(2 + SizeOutput + 6)   = 0     ! LdrZd 
    
    ! Initialize AllOutputs array
    CALL AllocAry( y%AllOutputs, 23+(2*SizeOutput), 'AllOutputs', TmpErrStat, TmpErrMsg )
    CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,RoutineName)
    
    y%AllOutputs = 0
    
    END SUBROUTINE LidarSim_InitializeOutputs
    
    
!#########################################################################################################################################################################  
    
    SUBROUTINE LidarSim_SetOutputs(y,p,Vlos,UnitVector,LoopGatesPerBeam,Time)
    
    IMPLICIT                                    NONE
    CHARACTER(*),                               PARAMETER       ::  RoutineName='LidarSim_SetOutputs'
    
    TYPE(LidarSim_OutputType),                  INTENT(INOUT)   ::  y
    TYPE(LidarSim_ParameterType),               INTENT(IN   )   ::  p
    REAL(ReKi),                                 INTENT(IN   )   ::  Vlos
    REAL(ReKi),                                 INTENT(IN   )   ::  UnitVector(3)
    INTEGER(IntKi),                             INTENT(IN   )   ::  LoopGatesPerBeam                    !from 0 to p%GatesPerBeam-1
    REAL(DbKi),                                 INTENT(IN   )   ::  Time
    
    !Local variables
    INTEGER(IntKi)                                              ::  LoopCounter
    REAL(ReKi)                                                  ::  Dot_LidarPosition_I(3)
    
    Dot_LidarPosition_I(1) = y%IMUOutputs(11)
    Dot_LidarPosition_I(2) = y%IMUOutputs(14)
    Dot_LidarPosition_I(3) = y%IMUOutputs(17)
    
    y%AllOutputs( 1 : 18 )  = y%IMUOutputs ( 1 : 18 )
    y%AllOutputs( 19 )      = p%MeasuringPoints_Spherical_L(2,p%LastMeasuringPoint+LoopGatesPerBeam)        !Azimuth
    y%AllOutputs( 20 )      = p%MeasuringPoints_Spherical_L(3,p%LastMeasuringPoint+LoopGatesPerBeam)        !Elevation
    y%AllOutputs( 21 )      = Time                                                                          !MeasTime
    y%AllOutputs( 22 )      = 1                                                                             !NewData
    y%AllOutputs( 23 )      = REAL(p%NextBeamID)                                                            !BeamID

    y%AllOutputs( 24 + LoopGatesPerBeam ) = p%MeasuringPoints_Spherical_L(1,p%LastMeasuringPoint+LoopGatesPerBeam)   !Rangegates
    y%AllOutputs( 24 + p%GatesPerBeam + LoopGatesPerBeam ) = Vlos + (  DOT_PRODUCT(Dot_LidarPosition_I,UnitVector))  !Output the measured V_los. Consiting of the windspeed and the movement of the measuring system itself
    
    DO LoopCounter = 1,SIZE(p%ValidOutputs)
        y%WriteOutput( LoopCounter ) = y%AllOutputs( p%ValidOutputs(LoopCounter) )
    END DO
    
    y%SwapOutputs( 1                        )   = y%AllOutputs( 22 )                                        !NewData
    y%SwapOutputs( 2                        )   = y%AllOutputs( 23 )                                        !BeamID
    y%SwapOutputs( 3 + LoopGatesPerBeam     )   = y%AllOutputs( 24 + p%GatesPerBeam + LoopGatesPerBeam )    !Vlos

    y%SwapOutputs( 2 + p%GatesPerBeam   + 1 )   = y%IMUOutputs(  1 )    ! LdrRoll
    y%SwapOutputs( 2 + p%GatesPerBeam   + 2 )   = y%IMUOutputs(  4 )    ! LdrPitch
    y%SwapOutputs( 2 + p%GatesPerBeam   + 3 )   = y%IMUOutputs(  7 )    ! LdrYaw
    y%SwapOutputs( 2 + p%GatesPerBeam   + 4 )   = y%IMUOutputs( 11 )    ! LdrXd
    y%SwapOutputs( 2 + p%GatesPerBeam   + 5 )   = y%IMUOutputs( 14 )    ! LdrYd
    y%SwapOutputs( 2 + p%GatesPerBeam   + 6 )   = y%IMUOutputs( 17 )    ! LdrZd
    
    END SUBROUTINE
    
    
!#########################################################################################################################################################################  
    
    END MODULE LidarSim_Subs