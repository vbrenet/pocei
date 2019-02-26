@isTest
public class testVbTools {
    @isTest static void test1() {
        String converted = vbTools.convertPersonAccountField('PC_abcd');
        System.Assert(converted == 'Abcd');
        converted = vbTools.convertPersonAccountField(converted);
        System.Assert(converted == 'abcd');
        converted = vbTools.convertPersonAccountField ('PC_123_456');
		System.Assert(converted == '123456');
        converted = vbTools.convertPersonAccountField ('PC_BIRTHDATE');
        System.Assert(converted == 'Birthdate');
        converted = vbTools.convertPersonAccountField ('PC_LAST_NAME');
        System.Assert(converted == 'LastName');
        converted = vbTools.convertPersonAccountField ('PC_BIR_RDFT_ZERTY_UJIOP');
        System.Assert(converted == 'BirRdftZertyUjiop');
    }

}