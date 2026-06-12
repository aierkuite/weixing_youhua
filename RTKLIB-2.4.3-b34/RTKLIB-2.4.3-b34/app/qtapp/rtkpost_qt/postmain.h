//---------------------------------------------------------------------------
#ifndef postmainH
#define postmainH
//---------------------------------------------------------------------------
#include <QString>
#include <QDialog>
#include <QThread>

#include "rtklib.h"

#include "ui_postmain.h"

class QShowEvent;
class QCloseEvent;
class QSettings;
class OptDialog;
class TextViewer;
class ConvDialog;


//Helper Class ------------------------------------------------------------------

class ProcessingThread : public QThread
{
    Q_OBJECT
public:
    prcopt_t prcopt;
    solopt_t solopt;
    filopt_t filopt;
    gtime_t ts,te;
    double ti,tu;
    int n,stat,diagena;
    char *infile[6],outfile[1024];
    char diagdir[1024];
    char *rov,*base;

    explicit ProcessingThread(QObject *parent);
    ~ProcessingThread();
    void addInput(const QString &);
    void addList(char * &sta, const QString & list);
protected:
    void run();

signals:
    void done(int);
};
//---------------------------------------------------------------------------

class MainForm : public QDialog, public Ui::MainForm
{
    Q_OBJECT

public slots:
    void BtnPlotClick       ();
    void BtnViewClick       ();
    void BtnToKMLClick      ();
    void BtnOptionClick     ();
    void BtnExecClick       ();
    void BtnAbortClick       ();
    void BtnExitClick       ();
    void BtnAboutClick      ();
	
    void BtnTime1Click      ();
    void BtnTime2Click      ();
    void BtnInputFile1Click ();
    void BtnInputFile3Click ();
    void BtnInputFile2Click ();
    void BtnInputFile4Click ();
    void BtnInputFile5Click ();
    void BtnOutputFileClick ();
    void BtnInputView1Click ();
    void BtnInputView3Click ();
    void BtnInputView2Click ();
    void BtnInputView4Click ();
    void BtnInputView5Click ();
    void BtnOutputView1Click();
    void BtnOutputView2Click();
    void BtnInputPlot1Click ();
    void BtnInputPlot2Click ();
    void BtnKeywordClick    ();
	
    void TimeStartClick     ();
    void TimeEndClick       ();
    void TimeIntFClick      ();
    void TimeUnitFClick     ();
	
    void InputFile1Change   ();
    void OutDirEnaClick();
    void BtnOutDirClick();
    void OutDirChange();
    void DiagOutEnaClick();
    void BtnDiagDirClick();
    void BtnInputFile6Click();
    void BtnInputView6Click();

    void FormCreate          ();
    void ProcessingFinished  (int);
    void ShowMsg(const QString  &msg);
protected:
    void showEvent           (QShowEvent*);
    void closeEvent          (QCloseEvent*);
    void  dragEnterEvent        (QDragEnterEvent *event);
    void  dropEvent             (QDropEvent *event);

private:

    OptDialog	 *optDialog;
    ConvDialog *convDialog;
    TextViewer *textViewer;

    void  ExecProc           (void);
    int  GetOption(prcopt_t &prcopt, solopt_t &solopt, filopt_t &filopt);
    int  ObsToNav (const QString &obsfile, QString &navfile);
	
    // 将界面输入的文件 URL 或普通路径转换为 RTKLIB 可用的本地路径
    // 参数：path 界面控件、命令行或历史记录中的路径文本
    // 返回值：归一化后的本地文件路径，非文件 URL 时保留原路径并转换为系统分隔符
    QString LocalFilePath(const QString &path) const;
    QString FilePath(const QString &file);
    QString DiagDefaultDir(const QString &outfile);
    void ReadList(QComboBox *, QSettings *ini,  const QString &key);
    void WriteList(QSettings *ini, const QString &key, const QComboBox *combo);
    void AddHist  (QComboBox *combo);
    int ExecCmd(const QString &cmd, int show);
	
    gtime_t GetTime1(void);
    gtime_t GetTime2(void);
    void SetOutFile(void);
    void SetTime1(gtime_t time);
    void SetTime2(gtime_t time);
    void UpdateEnable(void);
    void LoadOpt(void);
    void SaveOpt(void);
	
public:
    QString IniFile;
    int AbortFlag;
	
	// options
	int PosMode,Freq,Solution,DynamicModel,IonoOpt,TropOpt,RcvBiasEst;
	int Robust,WeightSnr;
	int ARIter,NumIter,CodeSmooth,TideCorr;
	int OutCntResetAmb,FixCntHoldAmb,LockCntFixAmb,RovPosType,RefPosType;
	int SatEphem,NavSys;
	int RovAntPcv,RefAntPcv,AmbRes,GloAmbRes,BdsAmbRes;
	int OutputHead,OutputOpt,OutputDatum;
	int OutputHeight,OutputGeoid,DebugTrace,DebugStatus,BaseLineConst;
	int SolFormat,TimeFormat,LatLonFormat,IntpRefObs,NetRSCorr,SatClkCorr;
	int SbasCorr,SbasCorr1,SbasCorr2,SbasCorr3,SbasCorr4,TimeDecimal;
	int SolStatic,SbasSat,MapFunc;
	int PosOpt[6];
	double ElMask,MaxAgeDiff,RejectThres,RejectGdop;
	double MeasErrR1,MeasErrR2,MeasErr2,MeasErr3,MeasErr4,MeasErr5;
	double SatClkStab,RovAntE,RovAntN,RovAntU,RefAntE,RefAntN,RefAntU;
	double PrNoise1,PrNoise2,PrNoise3,PrNoise4,PrNoise5;
	double ValidThresAR,ElMaskAR,ElMaskHold,SlipThres;
	double ThresAR2,ThresAR3;
	double RovPos[3],RefPos[3],BaseLine[2];
	snrmask_t SnrMask;
	
    QString RnxOpts1,RnxOpts2,PPPOpts;
    QString FieldSep,RovAnt,RefAnt,AntPcvFile,StaPosFile,PrecEphFile;
    QString NetRSCorrFile1,NetRSCorrFile2,SatClkCorrFile,GoogleEarthFile;
    QString GeoidDataFile,IonoFile,DCBFile,EOPFile,BLQFile;
    QString SbasCorrFile,SatPcvFile,ExSats;
    QString RovList,BaseList;
	
    void ViewFile(const QString &file);
    explicit MainForm(QWidget *parent=0);
};

//---------------------------------------------------------------------------
#endif
