(require :robot-interface "package://pr2eus/robot-interface.l")

(ros::load-ros-manifest "dynamic_reconfigure")
(ros::roseus-add-msgs "hrpsys_ros_bridge")
(ros::roseus-add-srvs "hrpsys")

(defclass rtm-ros-robot-interface
  :super robot-interface
  :slots ()
  )

(defmethod rtm-ros-robot-interface
  (:init
   (&rest args)
   (prog1
       (send-super* :init args)
     (ros::subscribe "/motor_states" hrpsys_ros_bridge::MotorStates
       #'send self :ros-state-callback-rtmros :groupname groupname)
     ))
  (:ros-state-callback-rtmros
   (msg)
   (dolist (key '(:temperature))
     (send self :set-robot-state1 key (send msg key))))
  (:temperature-vector () (cdr (assoc :temperature robot-state)))
  (:sendmsg
   (strs &optional (service-name "sendmsg"))
   (ros::service-call
    service-name
    (let ((req (instance dynamic_reconfigure::ReconfigureRequest :init)))
      (send (send req :config) :strs
	    (mapcar #'(lambda (str)
			(instance dynamic_reconfigure::StrParameter :init :name service-name :value str))
		    strs))
      req)))
  (:set-interpolation-mode (mode) (send self :sendmsg (list "setInterpolationMode" (format nil "~A" mode))))
  ;; just for seq debug
  (:wait-interpolation-for-seq-debug () (send self :sendmsg (list "waitInterpolation" "")))
  (:angle-vector-for-seq-debug
   (v tm)
   (send self :sendmsg
	 (list "setJointAngles"
	       (let ((str""))
		 (dotimes (i (length v)) (setq str (format nil "~A ~A" str (deg2rad (elt v i)))))
		 (format nil "~A ~A" str (* 1e-3 tm))))))
  ;;
  ;; CollisionDetectorService.idl
  (:set-tolerance
   (&key (tolerance 0.1) (link_pair_name "all"))
   (let* ((req (instance hrpsys::OpenHRP_CollisionDetectorService_setToleranceRequest :init
			 :link_pair_name link_pair_name
			 :tolerance tolerance)))
     (ros::service-call "CollisionDetectorServiceROSBridge/setTolerance" req)))
  ;; for logger
  (:save-log
   (fname)
   (ros::service-call
    "DataLoggerServiceROSBridge/save"
    (instance hrpsys::Openhrp_Dataloggerservice_saveRequest :init :basename fname))
   )
  ;; for seq
  (:setBasePose
   (&optional base-coords (tm 0.1))
   (unless base-coords
     (setq base-coords (send robot :worldcoords)))
   (let ((pos_req (instance hrpsys::OpenHRP_SequencePlayerService_setBasePosRequest :init))
         (rpy_req (instance hrpsys::OpenHRP_SequencePlayerService_setBaseRpyRequest :init)))
     (send pos_req :pos (scale 0.001 (send base-coords :pos)))
     (send pos_req :tm tm)
     (let ((rpy (coerce (car (send base-coords :rpy-angle)) float-vector)))
       (send rpy_req :rpy rpy)
       (send rpy_req :tm tm))
     (ros::service-call
      "SequencePlayerServiceROSBridge/setBasePos" pos_req)
     (ros::service-call
      "SequencePlayerServiceROSBridge/setBaseRpy" rpy_req)
     ))
  ;; just testing code
  (:addJointGroup (groupname jnames)
   (let ((req (instance hrpsys::OpenHRP_SequencePlayerService_addJointGroupRequest :init)))
     (send req :gname groupname)
     (send req :jnames jnames)
     (ros::service-call
      "SequencePlayerServiceROSBridge/addJointGroup" req)))
  (:setJointAnglesOfGroup (groupname av tm)
   (let ((req (instance hrpsys::OpenHRP_SequencePlayerService_setJointAnglesOfGroupRequest :init)))
     (send req :gname groupname)
     (send req :jvs av)
     (send req :tm tm)
     (ros::service-call
      "SequencePlayerServiceROSBridge/setJointAnglesOfGroup" req)))
#| ;; angle group sample
  (send *ri* :addJointgroup "larm" (send-all (send *robot* :larm :joint-list) :name))
  (send *ri* :setJointAnglesOfGroup "larm" (scale (/ pi 180.0) (send *robot* :larm :angle-vector)) 4.0)
  (send *ri* :waitinterpolationofgroup "larm")
|#
  (:enableCollisionDetection ()
   (let ((req (instance hrpsys::OpenHRP_CollisionDetectorService_enableCollisionDetectionRequest :init)))
     (ros::service-call
      "CollisionDetectorServiceROSBridge/enableCollisionDetection" req)))
  (:disableCollisionDetection ()
   (let ((req (instance hrpsys::OpenHRP_CollisionDetectorService_disableCollisionDetectionRequest :init)))
     (ros::service-call
      "CollisionDetectorServiceROSBridge/disableCollisionDetection" req)))
  (:waitInterpolationOfGroup (groupname)
   (let ((req (instance hrpsys::OpenHRP_SequencePlayerService_waitInterpolationOfGroupRequest :init)))
     (send req :gname groupname)
     (ros::service-call
      "SequencePlayerServiceROSBridge/waitInterpolationOfGroup" req)))
  (:setServoGainPercentage (name percentage)
   (let ((req (instance hrpsys::OpenHRP_RobotHardwareService_setServoGainPercentageRequest :init)))
     (send req :name name)
     (send req :percentage percentage)
     (ros::service-call
      "RobotHardwareServiceROSBridge/setServoGainPercentage" req)))
  )